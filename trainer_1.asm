; use sfx for success and failure

.586p
.model flat,stdcall
option casemap:none

include \masm32\include\windows.inc
include \masm32\include\masm32.inc
include \masm32\include\user32.inc
include \masm32\include\kernel32.inc
include \masm32\include\gdi32.inc
include \masm32\include\ole32.inc
include \masm32\include\comctl32.inc
include \masm32\include\ufmod.inc
include \masm32\include\winmm.inc
include \masm32\include\TextScroller.inc
include	\masm32\macros\macros.asm

;includelib \masm32\lib\ufmod.lib 
includelib \masm32\lib\masm32.lib 
includelib \masm32\lib\user32.lib
includelib \masm32\lib\kernel32.lib
includelib \masm32\lib\ole32.lib
includelib \masm32\lib\oleaut32.lib
includelib \masm32\lib\comctl32.lib
includelib \masm32\lib\gdi32.lib
;includelib \masm32\lib\winmm.lib
includelib \masm32\lib\TextScroller.lib

DlgProc PROTO :DWORD,:DWORD,:DWORD,:DWORD
MakeDialogTransparentValue	PROTO :DWORD,:DWORD
Scroller_proc PROTO :DWORD

.data
DlgName db "VGA",0
AppName db "Facewound trainer",0
target_window_name db "fwound",0
hook_failed_text db "Keyboard hook failed, exiting !",0
temp_buffer dd 0
hook_handle dd 0
hook_code dd 0
base dd 0
wParam_hook dd 0
lParam_hook dd 0
target_window_handle dd 0
target_pid dd 0
target_P_handle dd 0
health_patch db 90h,90h,90h,90h,90h,90h
health_restore db 0d9h, 96h, 0d8h, 03h, 00h, 00h
lives_restore db 0ffh, 8eh, 0d4h, 07h, 00h, 00h
ammo_restore db 0ffh, 08h

user32_string db "user32.dll",0
SetLayeredWindowAttributes_string db "SetLayeredWindowAttributes",0
MS_SANS_SERIF_string db "MS SANS SERIF",0
scr_text db "Facewound +3 trainer    Have fun with this crazy shooter !  More quality FOFF releases coming to you in the future !",0

.data?
hInstance HINSTANCE ?
CommandLine LPSTR ?
hBitmap HANDLE ?
gProc dd ?
gHwnd dd ?
gPID dd ?
dwOldProtect dd ?
dwNewProtect dd ?
Buffer db ?
jpeg_hresource dd ?
jpeg_hdata dd ?
jpeg_size dd ?
pSLWA dd ?
scr SCROLLER_STRUCT <>
lf LOGFONT <>

.const
IDB_JPEG equ 4000
SONG EQU 500
TRANSPARENT_VALUE equ 242

.code
start:
	invoke GetModuleHandle, NULL
	mov    hInstance,eax
;	invoke uFMOD_PlaySong,SONG,hInstance,XM_RESOURCE 
	invoke	BitmapFromResource,hInstance,IDB_JPEG
	mov	hBitmap,eax
	invoke DialogBoxParam, hInstance, offset DlgName,NULL,offset DlgProc,NULL
;	invoke uFMOD_PlaySong,0,0,0
	invoke ExitProcess,eax

DlgProc proc hWnd:HWND, uMsg:UINT, wParam:WPARAM, lParam:LPARAM
	LOCAL ps:PAINTSTRUCT
	LOCAL hdc:HDC
	LOCAL hMemDC:HDC
	LOCAL rect:RECT
	.IF uMsg==WM_INITDIALOG

		invoke MakeDialogTransparentValue,hWnd,TRANSPARENT_VALUE
		invoke Scroller_proc, hWnd
		mov dword ptr [temp_buffer], offset @Global_Hook 
		invoke SetWindowsHookEx, WH_KEYBOARD_LL , dword ptr [temp_buffer] , dword ptr [hInstance] , 0
		test eax,eax
		jz @hook_failed
		mov dword ptr [hook_handle] , eax
		
		invoke GetClientRect,hWnd,addr rect	
		invoke CreateRoundRectRgn,0,0,rect.right,rect.bottom,20,20
        invoke SetWindowRgn,hWnd,eax,TRUE
        
		INVOKE ShowWindow, hWnd,SW_SHOWNORMAL	
	    INVOKE UpdateWindow, hWnd
	.ELSEIF uMsg==WM_PAINT
		invoke BeginPaint,hWnd,addr ps
		mov    hdc,eax
		invoke CreateCompatibleDC,hdc
		mov    hMemDC,eax
	    invoke SelectObject,hMemDC, hBitmap
		invoke GetClientRect,hWnd,addr rect
		invoke BitBlt,hdc,0,0,rect.right,rect.bottom,hMemDC,0,0,SRCCOPY
		invoke DeleteDC,hMemDC
		invoke EndPaint,hWnd,addr ps
	.ELSEIF (uMsg==WM_CLOSE) || (uMsg==WM_RBUTTONUP)
        invoke PauseScroller, addr scr
        invoke DeleteObject,hBitmap
	    invoke UnhookWindowsHookEx , dword ptr [hook_handle]
	    invoke SendMessage,hWnd,WM_DESTROY,0,0
	.ELSEIF (uMsg==WM_DESTROY)
		invoke PostQuitMessage,0
    .ELSEIF uMsg==WM_LBUTTONDOWN
        invoke SendMessage,hWnd,WM_NCLBUTTONDOWN,HTCAPTION,0
	.ELSE
		xor eax,eax
		ret
	.ENDIF
	mov eax,TRUE
	ret

DlgProc endp

;*******************************************************************************************************

@Global_Hook:
mov eax, dword ptr [esp+4]
mov dword ptr [hook_code] , eax
mov eax, dword ptr [esp+8]
mov dword ptr [wParam_hook] , eax
mov eax, dword ptr [esp+0Ch]
mov dword ptr [lParam_hook] , eax

mov eax, dword ptr [eax]   ;EAX holds the virtual key code
.IF EAX==VK_F1
    call @F1_pressed
.ELSEIF EAX==VK_F2
	call @F2_pressed
.ELSEIF EAX==VK_F3
	call @F3_pressed
.ELSEIF EAX==VK_F4
	call @F4_pressed
.ENDIF
invoke CallNextHookEx, 0 , dword ptr [hook_code] , dword ptr [wParam_hook] , dword ptr [lParam_hook]
ret

@hook_failed:
invoke MessageBox , 0, offset hook_failed_text , offset AppName, MB_ICONERROR
invoke ExitProcess,eax

;*******************************************************************************************************
@F1_pressed:   ;health
invoke FindWindow , 0, offset target_window_name
.IF eax==0
    invoke MessageBeep , MB_ICONHAND
.ELSE
	mov dword ptr [target_window_handle],eax
    invoke GetWindowThreadProcessId, dword ptr [target_window_handle], offset target_pid
    invoke OpenProcess, PROCESS_ALL_ACCESS	, 0 , dword ptr [target_pid]
    mov dword ptr [target_P_handle] , eax
    invoke WriteProcessMemory, dword ptr [target_P_handle] , 004435a8h , offset health_patch , 6 , offset temp_buffer
.ENDIF
ret

@F2_pressed:    ;lives
invoke FindWindow , 0, offset target_window_name
.IF eax==0
    invoke MessageBeep , MB_ICONHAND
.ELSE
	mov dword ptr [target_window_handle],eax
    invoke GetWindowThreadProcessId, dword ptr [target_window_handle], offset target_pid
    invoke OpenProcess, PROCESS_ALL_ACCESS	, 0 , dword ptr [target_pid]
    mov dword ptr [target_P_handle] , eax
    invoke WriteProcessMemory, dword ptr [target_P_handle] , 004092cah , offset health_patch , 6 , offset temp_buffer
.ENDIF
ret

@F3_pressed:    ;ammo/no reload
invoke FindWindow , 0, offset target_window_name
.IF eax==0
    invoke MessageBeep , MB_ICONHAND
.ELSE
	mov dword ptr [target_window_handle],eax
    invoke GetWindowThreadProcessId, dword ptr [target_window_handle], offset target_pid
    invoke OpenProcess, PROCESS_ALL_ACCESS	, 0 , dword ptr [target_pid]
    mov dword ptr [target_P_handle] , eax
    invoke WriteProcessMemory, dword ptr [target_P_handle] , 0044870bh , offset health_patch , 2 , offset temp_buffer
.ENDIF    
ret

@F4_pressed:    ;back to normal
invoke FindWindow , 0, offset target_window_name
.IF eax==0
    invoke MessageBeep , MB_ICONHAND
.ELSE
	mov dword ptr [target_window_handle],eax
    invoke GetWindowThreadProcessId, dword ptr [target_window_handle], offset target_pid
    invoke OpenProcess, PROCESS_ALL_ACCESS	, 0 , dword ptr [target_pid]
    mov dword ptr [target_P_handle] , eax
    invoke WriteProcessMemory, dword ptr [target_P_handle] , 004435a8h , offset health_restore , 6 , offset temp_buffer
    invoke WriteProcessMemory, dword ptr [target_P_handle] , 004092cah , offset lives_restore , 6 , offset temp_buffer
    invoke WriteProcessMemory, dword ptr [target_P_handle] , 0044870bh , offset ammo_restore , 2 , offset temp_buffer
.ENDIF
ret

MakeDialogTransparentValue proc _dialoghandle:dword,_value:dword
	
	pushad
	
	invoke GetModuleHandle, offset user32_string
	invoke GetProcAddress,eax, offset SetLayeredWindowAttributes_string
	.if eax!=0
		;---yes, its win2k/xp system---
		mov edi,eax
		invoke GetWindowLong,_dialoghandle,GWL_EXSTYLE	;get EXSTYLE
		
		.if _value==255
			xor eax,WS_EX_LAYERED	;remove WS_EX_LAYERED
		.else
			or eax,WS_EX_LAYERED	;eax = oldstlye + new style(WS_EX_LAYERED)
		.endif
		
		invoke SetWindowLong,_dialoghandle,GWL_EXSTYLE,eax
		
		.if _value<255
			push LWA_ALPHA
			push _value						;set level of transparency
			push 0							;transparent color
			push _dialoghandle					;window handle
			call edi						;call SetLayeredWindowAttributes
		.endif	
	.endif
	
	popad
	ret
MakeDialogTransparentValue endp

	
Scroller_proc proc hwnd:HWND

	    m2m scr.scroll_hwnd,hwnd
		mov scr.scroll_text, offset scr_text
		
		mov scr.scroll_x,15
		mov scr.scroll_y,69
		
		mov scr.scroll_width,270
		
		invoke lstrcpy,addr lf.lfFaceName,offset MS_SANS_SERIF_string	
		mov lf.lfHeight,14
		mov lf.lfCharSet,DEFAULT_CHARSET	
		mov lf.lfQuality,ANTIALIASED_QUALITY
		invoke CreateFontIndirect,addr lf
		mov scr.scroll_hFont,eax
		
		mov scr.scroll_alpha,TRANSPARENT_VALUE
		mov scr.scroll_textcolor, 0b19b60h
		
		invoke CreateScroller,addr scr
ret
Scroller_proc endp

end start




