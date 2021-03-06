Sub loadMapper0 'NROM / CxROM
		For i As Integer = 0 To (header.prgSize*16*1024)-1
			cpu.memory(&h8000+i) = prgRom(i)
		Next
		If header.prgSize*16*1024 = 16384 Then
			For i As Integer = 0 To (header.prgSize*16*1024)-1
				cpu.memory(&hC000+i) = prgRom(i)
			Next
		End if
		For i as Integer = 0 To (header.chrSize*8*1024)-1
				ppu.VRAM(i) = chrRom(i)
		Next
End Sub
Sub loadMapper1 'MMC1
	Dim As UInteger loadOffset
	loadOffset = header.prgSize*&h4000 'Number of banks x 16KB
	loadOffset -= &h4000 'Get start of last bank
	
	For i As Integer = 0 To &h3FFF
		cpu.memory(&h8000+i) = prgRom(i)
		cpu.memory(&hC000+i) = prgRom(loadOffset+i)
	Next
End Sub
Sub loadMapper3 'CxROM
	For i As Integer = 0 To &h7FFF
		cpu.memory(&h8000+i) = prgRom(i)
	Next
End Sub
Sub loadMapper2 'UxROM
	Dim As UInteger loadOffset
	loadOffset = header.prgSize*&h4000 'Number of banks x 16KB
	loadOffset -= &h4000 'Get start of last bank
	For i As Integer = 0 To &H3FFF '16K bank
		cpu.memory(&h8000+i) = prgRom(i) 'Load Bank 1 into slot 1
		cpu.memory(&HC000+i) = prgRom(loadOffset+i)
	Next
End Sub
Sub loadMapper4 'MMC3
	Dim As UInteger loadOffset
	loadOffset = header.prgSize * &h4000
	loadOffset -= &h4000
	For i As Integer = 0 To &h1FFF
		cpu.memory(&h8000+i) = prgRom(i)
		cpu.memory(&hA000+i) = prgRom(&h2000+i)
	Next
	For i as Integer = 0 To &h3FFF
		cpu.memory(&hC000+i) = prgRom(loadOffset + i)
	Next
End Sub
Sub loadMapper7 'AxROM
	For i As Integer = 0 To &h7FFF
		cpu.memory(&h8000+i) = prgRom(i)
	Next
End Sub
Sub loadROM
	Dim As String progname, shpname, onechr
	'See if we got a filename from the command line or drag and drop
	If Command(1) <> "" Then
		progname = Command(1)
		GoTo gotname
	End If
		Print "Note: ROM must be in EXEPATH, else use drag and drop to load it!)"
	Print "Press ENTER to load the last booted ROM!"
	Input "Program to run (compiled, no header): ", progname 'Get a filename from user
	
	If progname <> "" Then progname = ExePath & "\" & progname else progname = lastrom

	gotname:
	If progname = "" Or Not FileExists(progname) Then 'Break if no such filename
		Cls
		Print "File not found: " & progname
		Sleep 3000
		CAE
	EndIf
	lastrom = progname
	writeini

	'remove path from filename
	For z As Integer = 1 To Len(progname) Step 1
		onechr = Right(Left(progname,z),1)
		If onechr = "\" Then
			onechr = ""
			shpname = ""
			gamename = ""
		EndIf
		gamename = gamename & onechr
		shpname = shpname & onechr
	Next
	gamename = Left(gamename,Len(gamename)-4)

	WindowTitle "StrawberryNES - " & shpname ' set window title
	Open progname For Binary As #1
	romsize = Lof(1)
	ReDim As UByte rom(romsize) ' make ROM be the size of the... ROM
	For i As Integer = 0 To romsize-1 'Load ROM into ROM memory
		Get #1, i+1, rom(i), 1
	Next
	Close #1

	'read header
	Open progname for binary as #1
	get #1, 1, header.signature()
	If Chr(header.signature(0)) <> "N" And Chr(header.signature(1)) <> "E" And Chr(header.signature(2)) <> "S" Then GoTo skipread
	Get #1, 5, header.prgSize
	Get #1, 6, header.chrSize
	Get #1, 7, header.Flags6
	Get #1, 8, header.Flags7
	Get #1, 9, header.prgRAMSize
	Get #1, 10, header.Flags9
	Get #1, 11, header.flags10
	Get #1, 12, header.zeros()
   skipread:
	If Chr(header.signature(0)) = "N" And Chr(header.signature(1)) = "E" And Chr(header.signature(2)) = "S" Then
		ReDim As UByte PrgROM(header.prgSize*16*1024)
		ReDim As UByte chrROM(header.chrSize*8*1024)
		ReDim As UByte prgRAM(header.prgRAMSize*8*1024)
		Get #1, 17, prgROM()
		Get #1, 17 + header.prgSize*16*1024, chrROM()
		emulatorMode = "NES"
	End If
	Close #1
	mapper = header.Flags6 Shr 4
	mapper Or= ((header.Flags7 Shr 4) And 4)
	If emulatorMode= "6502" Then
	'copy rom to cpu memory
	For i As Integer = 0 To romsize
		cpu.memory(i+&h0600) = rom(i) ' yes this could overflow, this is just a temp setup!
	Next
	ElseIf emulatorMode = "NES" Then
		Select Case mapper
			Case 0
				loadMapper0
			Case 1
				loadMapper1
			Case 2 
				loadMapper2
			Case 3
				loadMapper3 'Mapper 0 loads the same as 3
			Case 4
				loadMapper4
			Case 7
				loadMapper7
			Case Else 
			Beep  
			Cls 
			Print "Unsupported mapper"
			Sleep 2000
			Cls 
			CAE 
		End Select
			
		EndIf
		set_i
		cpu.pc = (cpu.memory(&hFFFD) Shl 8) Or cpu.memory(&hFFFC)	
#ifdef debugmode
'======================================================ONLY INCLUDED IF DEBUGMODE IS DEFINED!======================================================================
	If shpname = "autotest.nes" Then logcomp = 1 Else logcomp = 0
	If logcomp = 1 Then
		Dim dummy As String
		Open "nestest.log" For Input As #31
		cpu.pc = &HC000
	End If
'==================================================================================================================================================================
#EndIf
End Sub