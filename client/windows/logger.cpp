#include <iostream>
#include <windows.h>

HHOOK _k_hook;

LRESULT __stdcall processKey(int nCode, WPARAM wParam, LPARAM lParam) {
	PKBDLLHOOKSTRUCT key = (PKBDLLHOOKSTRUCT)lParam;
	if (wParam == WM_KEYDOWN && nCode == HC_ACTION) {
		std::cout << key->vkCode << " key was pressed" << std::endl;
	}
	
	return CallNextHookEx(NULL, nCode, wParam, lParam);
}

int main(int argc, char* argv[]) {
	_k_hook = SetWindowsHookEx(WH_KEYBOARD_LL, processKey, NULL, 0);
	MSG msg;
	while (GetMessage(&msg, NULL, 0, 0) != 0) {
		TranslateMessage(&msg);
		DispatchMessageW(&msg);
	}
	if (_k_hook) {
		UnhookWindowsHookEx(_k_hook);
	}
	return TRUE;
}