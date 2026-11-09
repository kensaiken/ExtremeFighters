// Lanzadores con icono: Instalar.exe abre el instalador (PowerShell oculto),
// Jugar.exe abre el juego recompilado con Zakuro, todo relativo a su carpeta.
#define _UNICODE
#include <windows.h>
#include <stdio.h>
#include <wchar.h>

static wchar_t dir[MAX_PATH];

static int exists(const wchar_t *rel) {
    wchar_t p[MAX_PATH * 2];
    swprintf(p, MAX_PATH * 2, L"%ls%ls", dir, rel);
    return GetFileAttributesW(p) != INVALID_FILE_ATTRIBUTES;
}

static DWORD run(wchar_t *cmd, const wchar_t *cwd, DWORD flags) {
    STARTUPINFOW si = { sizeof si };
    PROCESS_INFORMATION pi;
    if (!CreateProcessW(NULL, cmd, NULL, NULL, FALSE, flags, NULL, cwd, &si, &pi)) return 0;
    DWORD pid = pi.dwProcessId;
    CloseHandle(pi.hThread); CloseHandle(pi.hProcess);
    return pid;
}


#ifdef PLAY
typedef struct { DWORD pid; HWND hwnd; } Find;
static BOOL CALLBACK find_window(HWND w, LPARAM l) {
    Find *f = (Find *)l; DWORD pid = 0;
    GetWindowThreadProcessId(w, &pid);
    RECT r;
    if (pid == f->pid && IsWindowVisible(w) && GetWindow(w, GW_OWNER) == NULL && GetWindowRect(w, &r) && r.right - r.left > 200) {
        f->hwnd = w; return FALSE;
    }
    return TRUE;
}
/* Zakuro no tiene opcion de pantalla completa al arrancar: se pulsa F11
   (su tecla de pantalla completa) en cuanto su ventana aparece. */
static void fullscreen(DWORD pid) {
    Find f = { pid, NULL };
    for (int i = 0; i < 150 && !f.hwnd; i++) { Sleep(100); EnumWindows(find_window, (LPARAM)&f); }
    if (!f.hwnd) return;
    Sleep(800);
    SetForegroundWindow(f.hwnd);
    Sleep(150);
    INPUT in[2] = { 0 };
    in[0].type = INPUT_KEYBOARD; in[0].ki.wVk = VK_F11;
    in[1].type = INPUT_KEYBOARD; in[1].ki.wVk = VK_F11; in[1].ki.dwFlags = KEYEVENTF_KEYUP;
    SendInput(2, in, sizeof(INPUT));
}
#endif

static void trim(wchar_t *s) {
    size_t n = wcslen(s);
    while (n && (s[n-1] == L'\r' || s[n-1] == L'\n' || s[n-1] == L' ')) s[--n] = 0;
}

int WINAPI wWinMain(HINSTANCE h, HINSTANCE p, PWSTR args, int show) {
    GetModuleFileNameW(NULL, dir, MAX_PATH);
    wchar_t *slash = wcsrchr(dir, L'\\');
    if (slash) slash[1] = 0;
    static wchar_t cmd[4096], cwd[MAX_PATH * 2];
#ifdef PLAY
    /* Jugar.exe vive en la carpeta de instalacion: todo es relativo a ella,
       y APPDATA / LOCALAPPDATA / TEMP se redirigen a appdata\ para que
       Zakuro no escriba nada en el perfil de Windows (100% portatil). */
    wchar_t ini[MAX_PATH * 2], tid[64] = L"", rom[MAX_PATH] = L"", env[MAX_PATH * 2], opt[64] = L"";
    swprintf(ini, MAX_PATH * 2, L"%lsjugar.ini", dir);
    FILE *f = _wfopen(ini, L"r, ccs=UTF-8");
    if (f) { fgetws(tid, 64, f); fgetws(rom, MAX_PATH, f); fgetws(opt, 64, f); fclose(f); }
    trim(tid); trim(rom); trim(opt);
    if (!tid[0] || !rom[0] || !exists(L"zakuro\\zakuro.exe")) {
        MessageBoxW(NULL, L"El juego no esta instalado en esta carpeta. Abre Instalar.exe.\n\nThe game is not installed in this folder. Open Instalar.exe.",
                    L"Extreme Fighters", MB_ICONWARNING);
        return 1;
    }
    const wchar_t *sub[][2] = { { L"APPDATA", L"appdata\\Roaming" }, { L"LOCALAPPDATA", L"appdata\\Local" },
                                { L"TEMP", L"appdata\\Temp" }, { L"TMP", L"appdata\\Temp" } };
    for (int i = 0; i < 4; i++) {
        swprintf(env, MAX_PATH * 2, L"%ls%ls", dir, sub[i][1]);
        wchar_t parent[MAX_PATH * 2]; swprintf(parent, MAX_PATH * 2, L"%lsappdata", dir); CreateDirectoryW(parent, NULL);
        CreateDirectoryW(env, NULL);
        SetEnvironmentVariableW(sub[i][0], env);
    }
    swprintf(cwd, MAX_PATH * 2, L"%lszakuro", dir);
    swprintf(cmd, 4096,
        L"\"%lszakuro\\zakuro.exe\" --recompiled \"%lsnativo\\%ls.dll\" --data \"%lspartidas\" \"%lsjuego\\%ls\"",
        dir, dir, tid, dir, dir, rom);
    DWORD pid = run(cmd, cwd, 0);
    if (!pid) { MessageBoxW(NULL, L"No se pudo abrir zakuro.exe", L"Extreme Fighters", MB_ICONERROR); return 1; }
    /* tercera linea de jugar.ini: pantalla_completa=1 (0 para ventana) */
    if (wcscmp(opt, L"pantalla_completa=0") != 0) fullscreen(pid);
#else
    if (!exists(L"instalador.ps1") || !exists(L"bin\\3dsrecomp.exe") || !exists(L"bin\\Jugar.exe") || !exists(L"assets\\banner.png")) {
        MessageBoxW(NULL, L"Extrae TODO el ZIP en una carpeta y abre Instalar.exe desde ahi.\n\nExtract the WHOLE ZIP into a folder and open Instalar.exe from there.",
                    L"Extreme Fighters", MB_ICONERROR);
        return 1;
    }
    wchar_t sys[MAX_PATH];
    GetSystemDirectoryW(sys, MAX_PATH);
    swprintf(cmd, 4096,
        L"\"%ls\\WindowsPowerShell\\v1.0\\powershell.exe\" -NoProfile -ExecutionPolicy Bypass -STA -WindowStyle Hidden -File \"%lsinstalador.ps1\"",
        sys, dir);
    wcscpy(cwd, dir);
    if (!run(cmd, cwd, CREATE_NO_WINDOW)) { MessageBoxW(NULL, L"No se pudo abrir PowerShell.", L"Extreme Fighters", MB_ICONERROR); return 1; }
#endif
    return 0;
}
