section .data
	archivo db '/bin/sh',0
	hextable db '0123456789ABCDEF'
	dump db '00  '
	lf db 10
	barra db '|'
	imprimible db '................'
	par db '-h'
	texto_ayuda db 'Texto de ayuda.',10,'El programa se debe ejecutar de la siguiente manera: ',10,'$ ./volcar [-h] <archivo>',10,'<archivo>: La ruta a un archivo de cualquier formato, de tamanio maximo 1MB.',10,'-h: Imprime este mensaje de ayuda y termina la ejecucion normalmente.',10,'El programa muestra por pantalla el contenido del archivo pasado por parametro, organizado de la siguiente manera:',10,'[Direccion base]  [Contenido hexadecimal]  [Contenido ASCII]',10,'Codigos de salida:',10,'Terminacion con salida 0: terminacion normal.',10,'Terminacion con salida 1: terminacion anormal.',10,'Terminacion con salida 2: terminacion anormal por error en el archivo de entrada.',10,0
	
	
section .bss
	bufflen equ 1048576
	buffer resb bufflen
	
section .text
	global _start
_start:

	pop eax			;me fijo la cantidad de argumentos
	cmp eax, 2
	jl error1
	
	pop eax			;nombre del programa
	pop eax			;primer argumento
	mov word bx, [eax]
	mov word cx, [par]
	cmp ebx, ecx
	je ayuda		;si es -h imprimo el texto de ayuda

	mov ebx, eax		;direccion del archivo
	mov eax, 5		;sys_open
	mov ecx, 0		;sin permisos
	mov edx, 0
	int 80h

	cmp eax, 0
	jl error2		;error al abrir el archivo

	mov ebx, eax 		;guardo el fd en ebx
	mov eax, 3              ;sys_read
	mov ecx, buffer		;lugar donde guardar lo leido
	mov edx, bufflen	;cantidad a leer
	int 80h			;leo, cantidad leida guardada en eax

	cmp eax, 0
	je vacio
	
	mov edi, eax		;copio cantidad leida a edi
	xor ecx, ecx

	mov esi, 3		;auxiliar para darle formato a la salida (espacios entre valores = esi-2)
while:				;ecx cuenta el byte actual, edi la cantidad de bytes

	mov eax, ecx		;me fijo si estoy al principio de un bloque de 16 bytes
	mov ebx, 16
	xor edx, edx
	div eax, ebx
	cmp edx, 0
	jz  imp_direc		;si estoy al principio de un bloque de 16 bytes, imprimo la direccion
sigo:	
	
	cmp ecx, edi		;si ya se terminaron los bytes, completo con ceros y salgo
	je completo
	
	mov eax,[buffer+ecx]	;guardo en eax el valor del byte actual
	mov esi, 3
	call imp_byte		;imprimo el byte actual
	
	call llenar_ascii	;coloco el byte actual en la tabla de imprimibles
	inc ecx			

	mov eax, ecx 		;me fijo si estoy al final de un bloque de 16 bytes
	mov ebx, 16
	xor edx, edx
	div eax, ebx
	cmp edx, 0
	je nueva_linea		;si estoy al final de un bloque de 16 bytes, imprimo la tabla ascii y bajo una linea
	
	jmp while
	
completo:			;completo la linea con ceros

	mov eax, ecx
	mov ebx, 16
	xor edx, edx
	div eax, ebx
	cmp edx, 0
	je salida
	
	xor eax, eax
	mov esi, 3
	call imp_byte
	
	call llenar_ascii
	inc ecx

	jmp completo	

salida:				;imprimo la ultima tabla de imprimibles y una nueva linea
	call imp_ascii 		
	mov eax, 4
	mov ebx, 1
	mov ecx, lf
	mov edx, 1
	int 80h
vacio:				;cierro el archivo

	mov eax, 6
	int 80h
	
	mov eax, 1		;termino exitosamente
	mov ebx, 0
	int 80h
error1:				;terminacion anormal
	mov eax, 1
	mov ebx, 1
	int 80h
error2:				;terminacion anormal por error en el archivo de entrada
	mov eax, 1
	mov ebx, 2
	int 80h

nueva_linea: 			;imprime la tabla de valores imprimibles actual y baja una linea
	call imp_ascii

	push eax
	push ebx
	push ecx
	push edx
	
	mov eax, 4
	mov ebx, 1
	mov ecx, lf
	mov edx, 1
	int 80h

	pop edx
	pop ecx
	pop ebx
	pop eax
	
	jmp while

imp_byte:			;imprime el contenido del registro al
	push eax
	push ebx
	push ecx
	push edx

	mov eax, ecx 		
	mov ebx, 16
	xor edx, edx
	div eax, ebx
	cmp edx, 8
	je esp_dos		;si estoy en el octavo byte de la fila, imprimo dos espacios
	cmp edx, 16
	je esp_dos		;si estoy en el ultimo byte de ña fila, imprimo dos espacios
	
sig_imp_byte:

	pop edx
	pop ecx
	pop ebx
	pop eax

	push eax
	push ebx
	push ecx
	push edx
	
	mov bl, al 		;copio el contenido
	shr bl, 4 		;me quedo con los 4 msb
	mov cl, [hextable+ebx] 	;busco su representacion en la tabla hex
	mov [dump], cl 		;lo copio a memoria
	
	mov bl, al		;copio el contenido
	and bl, 0xf		;me quedo con los 4 lsb
	mov cl, [hextable+ebx] 	;busco su representacion en la tabla hex
	mov [dump+1], cl	;lo copio a memoria

	mov eax, 4		;imprimo
	mov ebx, 1
	mov ecx, dump
	mov edx, esi
	int 80h

	pop edx
	pop ecx
	pop ebx
	pop eax

	ret

esp_dos:		
	mov esi, 4
	jmp sig_imp_byte

imp_ascii: 			;imprime la tabla de valores imprimibles
	push eax
	push ebx
	push ecx
	push edx


	mov eax, 4
	mov ebx, 1
	mov ecx, barra
	mov edx, 1
	int 80h
	
	mov eax, 4
	mov ebx, 1
	mov ecx, imprimible
	mov edx, 16
	int 80h
	
	mov eax, 4
	mov ebx, 1
	mov ecx, barra
	mov edx, 1
	int 80h
	
	pop edx
	pop ecx
	pop ebx
	pop eax
	ret

llenar_ascii: 			;coloca el valor de eax en el lugar correspondiente de 
				;la tabla de valores. Si no es imprimible pone un punto
	pusha
	and eax, 0xff 	
	cmp eax, 32
	jl noimp
	cmp eax, 127
	je noimp
	
sigo_llenar:
	mov ebx, eax		;hallo la posicion en la tabla y guardo el valor
	mov eax, ecx
	mov ecx, 16
	xor edx, edx
	div eax, ecx
	mov [imprimible+edx], ebx
	
	popa
	ret
	
noimp:
	mov eax, 46
	jmp sigo_llenar

imp_direc:			;imprime la direccion actual de a 2 digitos, empezando por los msb
	pusha
	
	mov esi, 2
	mov eax, ecx
	and eax, 0xff000000
	shr eax, 24
	call imp_byte		

	mov eax, ecx
	and eax, 0x00ff0000
	shr eax, 16
	call imp_byte

	mov eax, ecx
	and eax, 0x0000ff00
	shr eax, 8
	call imp_byte

	mov esi, 4
	mov eax, ecx
	and eax, 0x000000ff
	call imp_byte

	popa
	jmp sigo

ayuda:				;imprime el texto de ayuda y termina exitosamente
	mov eax, 4
	mov ebx, 1
	mov ecx, texto_ayuda
	mov edx, 613
	int 80h
	
	mov eax, 1
	mov ebx, 0
	int 80h
