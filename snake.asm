format PE64 console
entry start

include 'win64a.inc'

GRID_W = 40
GRID_H = 20
MAX_CELLS = GRID_W * GRID_H
MAX_OBSTACLES = 32

BOARD_X = 2
BOARD_Y = 2
HUD_X = BOARD_X + GRID_W + 6

DIR_UP = 0
DIR_RIGHT = 1
DIR_DOWN = 2
DIR_LEFT = 3

FOOD_APPLE = 0
FOOD_BONUS = 1
FOOD_SLOW = 2
FOOD_RUSH = 3
FOOD_TRIM = 4
FOOD_TYPES = 5

COLOR_DEFAULT = 07h
COLOR_MUTED = 08h
COLOR_WALL = 0Bh
COLOR_SNAKE_HEAD = 0Ah
COLOR_SNAKE_BODY = 02h
COLOR_FOOD = 0Ch
COLOR_BONUS = 0Eh
COLOR_SLOW = 0Dh
COLOR_RUSH = 09h
COLOR_TRIM = 0Fh
COLOR_OBSTACLE = 06h
COLOR_TITLE = 0Bh
COLOR_TEXT = 0Fh
COLOR_SCORE = 0Ah
COLOR_WARNING = 0Ch

VK_BACK = 08h
VK_RETURN = 0Dh
VK_ESCAPE = 1Bh
VK_LEFT = 25h
VK_UP = 26h
VK_RIGHT = 27h
VK_DOWN = 28h

section '.text' code readable executable

start:
        sub     rsp, 8

        invoke  SetConsoleTitleA, addr appTitle
        invoke  GetStdHandle, STD_OUTPUT_HANDLE
        mov     [hOut], rax

        call    HideCursor
        call    Randomize
        call    LoadHighScore

.menu:
        call    ShowTitle
        call    ReadMenuKey
        cmp     al, 0
        je      .exit

        mov     [difficulty], al
        call    NewGame
        call    GameLoop

        cmp     byte [quitGame], 1
        jne     .menu

.exit:
        call    SaveHighScore
        invoke  SetConsoleTextAttribute, [hOut], COLOR_DEFAULT
        invoke  ExitProcess, 0

proc GameLoop
.loop:
        call    PollControls

        cmp     byte [quitGame], 1
        je      .done
        cmp     byte [backToMenu], 1
        je      .done
        cmp     byte [restartGame], 1
        je      .restart

        cmp     byte [paused], 1
        je      .paused

        call    MoveSnake
        call    RenderGame

        cmp     byte [gameOver], 1
        je      .gameOver

        mov     eax, [tickDelay]
        invoke  Sleep, eax
        jmp     .loop

.paused:
        call    RenderGame
        call    DrawPauseMessage
        invoke  Sleep, 80
        jmp     .loop

.gameOver:
        call    ShowGameOver
        cmp     byte [restartGame], 1
        je      .restart
        jmp     .done

.restart:
        call    UpdateHighScore
        call    SaveHighScore
        mov     byte [restartGame], 0
        call    NewGame
        jmp     .loop

.done:
        call    UpdateHighScore
        call    SaveHighScore
        ret
endp

proc NewGame
        call    ClearScreen

        mov     dword [score], 0
        mov     dword [level], 1
        mov     dword [speedMod], 0
        mov     dword [snakeLen], 5
        mov     byte [direction], DIR_RIGHT
        mov     byte [nextDirection], DIR_RIGHT
        mov     byte [paused], 0
        mov     byte [gameOver], 0
        mov     byte [quitGame], 0
        mov     byte [backToMenu], 0
        mov     byte [restartGame], 0
        mov     byte [newRecord], 0

        mov     byte [snakeX + 0], 20
        mov     byte [snakeY + 0], 10
        mov     byte [snakeX + 1], 19
        mov     byte [snakeY + 1], 10
        mov     byte [snakeX + 2], 18
        mov     byte [snakeY + 2], 10
        mov     byte [snakeX + 3], 17
        mov     byte [snakeY + 3], 10
        mov     byte [snakeX + 4], 16
        mov     byte [snakeY + 4], 10

        movzx   eax, byte [difficulty]
        cmp     eax, 1
        je      .easy
        cmp     eax, 3
        je      .hard
        mov     dword [obstacleTarget], 14
        jmp     .obstacles

.easy:
        mov     dword [obstacleTarget], 8
        jmp     .obstacles

.hard:
        mov     dword [obstacleTarget], 22

.obstacles:
        call    BuildObstacles
        call    SpawnFood
        call    UpdateLevelAndSpeed
        call    RenderGame
        ret
endp

proc HideCursor
        invoke  SetConsoleCursorInfo, [hOut], addr cursorInfo
        ret
endp

proc ClearScreen uses rbx
        mov     dword [drawY], 0

.row:
        cmp     dword [drawY], 32
        jge     .done
        mov     eax, [drawY]
        fastcall WriteStringAt, 0, eax, addr blankLine, COLOR_DEFAULT
        inc     dword [drawY]
        jmp     .row

.done:
        ret
endp

proc ShowTitle
        call    ClearScreen
        fastcall WriteStringAt, 18, 4, addr appTitle, COLOR_TITLE
        fastcall WriteStringAt, 14, 6, addr titleTagline, COLOR_TEXT
        fastcall WriteStringAt, 14, 9, addr optionEasy, COLOR_TEXT
        fastcall WriteStringAt, 14, 10, addr optionNormal, COLOR_TEXT
        fastcall WriteStringAt, 14, 11, addr optionHard, COLOR_TEXT
        fastcall WriteStringAt, 14, 13, addr optionQuit, COLOR_MUTED
        fastcall WriteStringAt, 14, 16, addr highScoreLabel, COLOR_MUTED
        fastcall WriteUIntAt, 26, 16, [bestScore], COLOR_SCORE
        fastcall WriteStringAt, 14, 19, addr menuHint, COLOR_MUTED
        ret
endp

proc ReadMenuKey
.wait:
        invoke  GetAsyncKeyState, '1'
        test    ax, 8000h
        jnz     .easy
        invoke  GetAsyncKeyState, '2'
        test    ax, 8000h
        jnz     .normal
        invoke  GetAsyncKeyState, '3'
        test    ax, 8000h
        jnz     .hard
        invoke  GetAsyncKeyState, VK_RETURN
        test    ax, 8000h
        jnz     .normal
        invoke  GetAsyncKeyState, 'Q'
        test    ax, 8000h
        jnz     .quit
        invoke  GetAsyncKeyState, VK_ESCAPE
        test    ax, 8000h
        jnz     .quit
        invoke  Sleep, 60
        jmp     .wait

.easy:
        mov     al, 1
        ret

.normal:
        mov     al, 2
        ret

.hard:
        mov     al, 3
        ret

.quit:
        xor     al, al
        ret
endp

proc PollControls
        invoke  GetAsyncKeyState, 'Q'
        test    ax, 8000h
        jnz     .quit
        invoke  GetAsyncKeyState, VK_ESCAPE
        test    ax, 8000h
        jnz     .quit

        invoke  GetAsyncKeyState, 'M'
        test    ax, 0001h
        jnz     .menu

        invoke  GetAsyncKeyState, 'R'
        test    ax, 0001h
        jnz     .restart

        invoke  GetAsyncKeyState, 'P'
        test    ax, 0001h
        jnz     .togglePause

        invoke  GetAsyncKeyState, 'W'
        test    ax, 8000h
        jnz     .up
        invoke  GetAsyncKeyState, VK_UP
        test    ax, 8000h
        jnz     .up

        invoke  GetAsyncKeyState, 'S'
        test    ax, 8000h
        jnz     .down
        invoke  GetAsyncKeyState, VK_DOWN
        test    ax, 8000h
        jnz     .down

        invoke  GetAsyncKeyState, 'A'
        test    ax, 8000h
        jnz     .left
        invoke  GetAsyncKeyState, VK_LEFT
        test    ax, 8000h
        jnz     .left

        invoke  GetAsyncKeyState, 'D'
        test    ax, 8000h
        jnz     .right
        invoke  GetAsyncKeyState, VK_RIGHT
        test    ax, 8000h
        jnz     .right
        ret

.up:
        mov     al, DIR_UP
        call    SetNextDirection
        ret

.down:
        mov     al, DIR_DOWN
        call    SetNextDirection
        ret

.left:
        mov     al, DIR_LEFT
        call    SetNextDirection
        ret

.right:
        mov     al, DIR_RIGHT
        call    SetNextDirection
        ret

.togglePause:
        xor     byte [paused], 1
        ret

.restart:
        mov     byte [restartGame], 1
        ret

.menu:
        mov     byte [backToMenu], 1
        ret

.quit:
        mov     byte [quitGame], 1
        ret
endp

proc SetNextDirection
        mov     bl, [direction]
        cmp     al, DIR_UP
        jne     .notUp
        cmp     bl, DIR_DOWN
        je      .done
        jmp     .set

.notUp:
        cmp     al, DIR_DOWN
        jne     .notDown
        cmp     bl, DIR_UP
        je      .done
        jmp     .set

.notDown:
        cmp     al, DIR_LEFT
        jne     .notLeft
        cmp     bl, DIR_RIGHT
        je      .done
        jmp     .set

.notLeft:
        cmp     bl, DIR_LEFT
        je      .done

.set:
        mov     [nextDirection], al

.done:
        ret
endp

proc MoveSnake uses rbx rsi rdi
        mov     al, [nextDirection]
        mov     [direction], al

        mov     al, [snakeX]
        mov     [newX], al
        mov     al, [snakeY]
        mov     [newY], al

        mov     al, [direction]
        cmp     al, DIR_UP
        je      .goUp
        cmp     al, DIR_DOWN
        je      .goDown
        cmp     al, DIR_LEFT
        je      .goLeft
        inc     byte [newX]
        jmp     .bounds

.goUp:
        dec     byte [newY]
        jmp     .bounds

.goDown:
        inc     byte [newY]
        jmp     .bounds

.goLeft:
        dec     byte [newX]

.bounds:
        movzx   eax, byte [newX]
        cmp     eax, GRID_W
        jae     .die
        movzx   eax, byte [newY]
        cmp     eax, GRID_H
        jae     .die

        mov     al, [newX]
        mov     [tempX], al
        mov     al, [newY]
        mov     [tempY], al
        call    IsCellObstacle
        cmp     al, 1
        je      .die

        mov     byte [ateFood], 0
        mov     al, [newX]
        cmp     al, [foodX]
        jne     .selfCheck
        mov     al, [newY]
        cmp     al, [foodY]
        jne     .selfCheck
        mov     byte [ateFood], 1

.selfCheck:
        mov     ecx, [snakeLen]
        cmp     byte [ateFood], 1
        je      .checkAll
        dec     ecx

.checkAll:
        xor     esi, esi

.selfLoop:
        cmp     esi, ecx
        jge     .move
        mov     al, [snakeX + rsi]
        cmp     al, [newX]
        jne     .nextSelf
        mov     al, [snakeY + rsi]
        cmp     al, [newY]
        je      .die

.nextSelf:
        inc     esi
        jmp     .selfLoop

.move:
        mov     dword [growAmount], 0
        cmp     byte [ateFood], 1
        jne     .shift
        call    PrepareFoodEffect

.shift:
        mov     eax, [snakeLen]
        add     eax, [growAmount]
        cmp     eax, MAX_CELLS
        jbe     .storeLen
        mov     eax, MAX_CELLS

.storeLen:
        mov     [snakeLen], eax
        mov     ecx, eax
        dec     ecx

.shiftLoop:
        cmp     ecx, 0
        jle     .placeHead
        movsxd  rdi, ecx
        lea     rsi, [rdi - 1]
        mov     al, [snakeX + rsi]
        mov     [snakeX + rdi], al
        mov     al, [snakeY + rsi]
        mov     [snakeY + rdi], al
        dec     ecx
        jmp     .shiftLoop

.placeHead:
        mov     al, [newX]
        mov     [snakeX], al
        mov     al, [newY]
        mov     [snakeY], al

        cmp     byte [ateFood], 1
        jne     .finish
        call    ApplyFoodEffect
        call    SpawnFood
        invoke  Beep, 880, 30

.finish:
        call    UpdateLevelAndSpeed
        ret

.die:
        mov     byte [gameOver], 1
        call    UpdateHighScore
        invoke  Beep, 220, 140
        ret
endp

proc PrepareFoodEffect
        movzx   eax, byte [foodKind]
        cmp     eax, FOOD_BONUS
        jne     .normalGrowth
        mov     dword [growAmount], 2
        ret

.normalGrowth:
        cmp     eax, FOOD_TRIM
        je      .noGrowth
        mov     dword [growAmount], 1
        ret

.noGrowth:
        mov     dword [growAmount], 0
        ret
endp

proc ApplyFoodEffect
        movzx   eax, byte [foodKind]
        cmp     eax, FOOD_APPLE
        je      .apple
        cmp     eax, FOOD_BONUS
        je      .bonus
        cmp     eax, FOOD_SLOW
        je      .slow
        cmp     eax, FOOD_RUSH
        je      .rush
        cmp     eax, FOOD_TRIM
        je      .trim
        ret

.apple:
        add     dword [score], 10
        ret

.bonus:
        add     dword [score], 30
        ret

.slow:
        add     dword [score], 15
        add     dword [speedMod], 14
        ret

.rush:
        add     dword [score], 20
        sub     dword [speedMod], 12
        ret

.trim:
        add     dword [score], 5
        mov     eax, [snakeLen]
        cmp     eax, 6
        jbe     .trimDone
        sub     eax, 2
        mov     [snakeLen], eax

.trimDone:
        ret
endp

proc UpdateLevelAndSpeed uses rbx
        mov     eax, [score]
        xor     edx, edx
        mov     ebx, 50
        div     ebx
        inc     eax
        cmp     eax, 9
        jbe     .storeLevel
        mov     eax, 9

.storeLevel:
        mov     [level], eax

        movzx   eax, byte [difficulty]
        cmp     eax, 1
        je      .easy
        cmp     eax, 3
        je      .hard
        mov     eax, 115
        jmp     .baseDone

.easy:
        mov     eax, 150
        jmp     .baseDone

.hard:
        mov     eax, 85

.baseDone:
        add     eax, [speedMod]
        mov     ebx, [level]
        dec     ebx
        imul    ebx, 8
        sub     eax, ebx
        cmp     eax, 45
        jge     .maxCheck
        mov     eax, 45

.maxCheck:
        cmp     eax, 220
        jle     .storeDelay
        mov     eax, 220

.storeDelay:
        mov     [tickDelay], eax
        ret
endp

proc BuildObstacles uses rsi
        mov     dword [obstacleCount], 0

.loop:
        mov     eax, [obstacleCount]
        cmp     eax, [obstacleTarget]
        jge     .done

.retry:
        call    RandomCell
        call    IsCellOnSnake
        cmp     al, 1
        je      .retry
        call    IsCellObstacle
        cmp     al, 1
        je      .retry

        mov     esi, [obstacleCount]
        mov     al, [tempX]
        mov     [obstacleX + rsi], al
        mov     al, [tempY]
        mov     [obstacleY + rsi], al
        inc     dword [obstacleCount]
        jmp     .loop

.done:
        ret
endp

proc SpawnFood
.retry:
        call    RandomCell
        call    IsCellBlocked
        cmp     al, 1
        je      .retry

        mov     al, [tempX]
        mov     [foodX], al
        mov     al, [tempY]
        mov     [foodY], al

        mov     ecx, FOOD_TYPES
        call    RandomRange
        mov     [foodKind], al
        ret
endp

proc RandomCell
        mov     ecx, GRID_W
        call    RandomRange
        mov     [tempX], al
        mov     ecx, GRID_H
        call    RandomRange
        mov     [tempY], al
        ret
endp

proc IsCellBlocked
        call    IsCellOnSnake
        cmp     al, 1
        je      .done
        call    IsCellObstacle

.done:
        ret
endp

proc IsCellOnSnake uses rsi
        xor     esi, esi

.loop:
        cmp     esi, [snakeLen]
        jge     .no
        mov     al, [snakeX + rsi]
        cmp     al, [tempX]
        jne     .next
        mov     al, [snakeY + rsi]
        cmp     al, [tempY]
        je      .yes

.next:
        inc     esi
        jmp     .loop

.yes:
        mov     al, 1
        ret

.no:
        xor     al, al
        ret
endp

proc IsCellObstacle uses rsi
        xor     esi, esi

.loop:
        cmp     esi, [obstacleCount]
        jge     .no
        mov     al, [obstacleX + rsi]
        cmp     al, [tempX]
        jne     .next
        mov     al, [obstacleY + rsi]
        cmp     al, [tempY]
        je      .yes

.next:
        inc     esi
        jmp     .loop

.yes:
        mov     al, 1
        ret

.no:
        xor     al, al
        ret
endp

proc Randomize
        invoke  GetTickCount
        test    eax, eax
        jnz     .store
        mov     eax, 2463534242

.store:
        mov     [rngState], eax
        ret
endp

proc RandomRange
        push    rdx
        push    rcx
        call    RandomNext
        pop     rcx
        xor     edx, edx
        div     ecx
        mov     eax, edx
        pop     rdx
        ret
endp

proc RandomNext
        mov     eax, [rngState]
        mov     edx, eax
        shl     edx, 13
        xor     eax, edx
        mov     edx, eax
        shr     edx, 17
        xor     eax, edx
        mov     edx, eax
        shl     edx, 5
        xor     eax, edx
        mov     [rngState], eax
        ret
endp

proc RenderGame uses rbx
        mov     dword [drawY], 0

.row:
        cmp     dword [drawY], GRID_H + 2
        jge     .hud
        mov     dword [drawX], 0

.col:
        cmp     dword [drawX], GRID_W + 2
        jge     .nextRow
        call    ResolveCellVisual

        mov     eax, [drawX]
        add     eax, BOARD_X
        mov     ebx, [drawY]
        add     ebx, BOARD_Y
        movzx   ecx, byte [cellChar]
        mov     edx, [cellColor]
        fastcall WriteCharAt, eax, ebx, ecx, edx

        inc     dword [drawX]
        jmp     .col

.nextRow:
        inc     dword [drawY]
        jmp     .row

.hud:
        call    DrawHud
        ret
endp

proc ResolveCellVisual uses rsi
        mov     eax, [drawY]
        cmp     eax, 0
        je      .wall
        cmp     eax, GRID_H + 1
        je      .wall
        mov     eax, [drawX]
        cmp     eax, 0
        je      .wall
        cmp     eax, GRID_W + 1
        je      .wall

        dec     eax
        mov     [tempX], al
        mov     eax, [drawY]
        dec     eax
        mov     [tempY], al

        mov     al, [snakeX]
        cmp     al, [tempX]
        jne     .body
        mov     al, [snakeY]
        cmp     al, [tempY]
        jne     .body
        mov     byte [cellChar], '@'
        mov     dword [cellColor], COLOR_SNAKE_HEAD
        ret

.body:
        mov     esi, 1

.bodyLoop:
        cmp     esi, [snakeLen]
        jge     .food
        mov     al, [snakeX + rsi]
        cmp     al, [tempX]
        jne     .nextBody
        mov     al, [snakeY + rsi]
        cmp     al, [tempY]
        je      .bodyHit

.nextBody:
        inc     esi
        jmp     .bodyLoop

.bodyHit:
        mov     byte [cellChar], 'o'
        mov     dword [cellColor], COLOR_SNAKE_BODY
        ret

.food:
        mov     al, [foodX]
        cmp     al, [tempX]
        jne     .obstacle
        mov     al, [foodY]
        cmp     al, [tempY]
        jne     .obstacle
        call    FoodVisual
        ret

.obstacle:
        call    IsCellObstacle
        cmp     al, 1
        jne     .empty
        mov     byte [cellChar], '+'
        mov     dword [cellColor], COLOR_OBSTACLE
        ret

.empty:
        mov     byte [cellChar], ' '
        mov     dword [cellColor], COLOR_DEFAULT
        ret

.wall:
        mov     byte [cellChar], '#'
        mov     dword [cellColor], COLOR_WALL
        ret
endp

proc FoodVisual
        movzx   eax, byte [foodKind]
        cmp     eax, FOOD_APPLE
        je      .apple
        cmp     eax, FOOD_BONUS
        je      .bonus
        cmp     eax, FOOD_SLOW
        je      .slow
        cmp     eax, FOOD_RUSH
        je      .rush

        mov     byte [cellChar], '-'
        mov     dword [cellColor], COLOR_TRIM
        ret

.apple:
        mov     byte [cellChar], '*'
        mov     dword [cellColor], COLOR_FOOD
        ret

.bonus:
        mov     byte [cellChar], '$'
        mov     dword [cellColor], COLOR_BONUS
        ret

.slow:
        mov     byte [cellChar], '+'
        mov     dword [cellColor], COLOR_SLOW
        ret

.rush:
        mov     byte [cellChar], '!'
        mov     dword [cellColor], COLOR_RUSH
        ret
endp

proc DrawHud
        mov     dword [drawY], 2

.clear:
        cmp     dword [drawY], 23
        jge     .write
        mov     eax, [drawY]
        fastcall WriteStringAt, HUD_X, eax, addr hudBlank, COLOR_DEFAULT
        inc     dword [drawY]
        jmp     .clear

.write:
        fastcall WriteStringAt, HUD_X, 2, addr scoreLabel, COLOR_MUTED
        fastcall WriteUIntAt, HUD_X + 8, 2, [score], COLOR_SCORE
        fastcall WriteStringAt, HUD_X, 3, addr bestLabel, COLOR_MUTED
        fastcall WriteUIntAt, HUD_X + 8, 3, [bestScore], COLOR_SCORE
        fastcall WriteStringAt, HUD_X, 4, addr levelLabel, COLOR_MUTED
        fastcall WriteUIntAt, HUD_X + 8, 4, [level], COLOR_TEXT
        fastcall WriteStringAt, HUD_X, 5, addr lengthLabel, COLOR_MUTED
        fastcall WriteUIntAt, HUD_X + 8, 5, [snakeLen], COLOR_TEXT

        fastcall WriteStringAt, HUD_X, 8, addr foodLegendTitle, COLOR_TEXT
        fastcall WriteStringAt, HUD_X, 9, addr foodLegendApple, COLOR_FOOD
        fastcall WriteStringAt, HUD_X, 10, addr foodLegendBonus, COLOR_BONUS
        fastcall WriteStringAt, HUD_X, 11, addr foodLegendSlow, COLOR_SLOW
        fastcall WriteStringAt, HUD_X, 12, addr foodLegendRush, COLOR_RUSH
        fastcall WriteStringAt, HUD_X, 13, addr foodLegendTrim, COLOR_TRIM

        fastcall WriteStringAt, HUD_X, 16, addr controlsTitle, COLOR_TEXT
        fastcall WriteStringAt, HUD_X, 17, addr controlsMove, COLOR_MUTED
        fastcall WriteStringAt, HUD_X, 18, addr controlsPause, COLOR_MUTED
        fastcall WriteStringAt, HUD_X, 19, addr controlsRestart, COLOR_MUTED
        fastcall WriteStringAt, HUD_X, 20, addr controlsMenu, COLOR_MUTED
        fastcall WriteStringAt, HUD_X, 21, addr controlsQuit, COLOR_MUTED
        ret
endp

proc DrawPauseMessage
        fastcall WriteStringAt, 15, 12, addr pauseText, COLOR_BONUS
        ret
endp

proc ShowGameOver
        call    UpdateHighScore
        call    SaveHighScore
        fastcall WriteStringAt, 13, 11, addr gameOverText, COLOR_WARNING
        fastcall WriteStringAt, 10, 13, addr finalScoreText, COLOR_TEXT
        fastcall WriteUIntAt, 23, 13, [score], COLOR_SCORE
        cmp     byte [newRecord], 1
        jne     .prompt
        fastcall WriteStringAt, 10, 14, addr newRecordText, COLOR_BONUS

.prompt:
        fastcall WriteStringAt, 7, 16, addr gameOverPrompt, COLOR_MUTED

.wait:
        invoke  GetAsyncKeyState, 'R'
        test    ax, 8000h
        jnz     .restart
        invoke  GetAsyncKeyState, VK_RETURN
        test    ax, 8000h
        jnz     .restart
        invoke  GetAsyncKeyState, 'M'
        test    ax, 8000h
        jnz     .menu
        invoke  GetAsyncKeyState, 'Q'
        test    ax, 8000h
        jnz     .quit
        invoke  GetAsyncKeyState, VK_ESCAPE
        test    ax, 8000h
        jnz     .quit
        invoke  Sleep, 60
        jmp     .wait

.restart:
        mov     byte [restartGame], 1
        ret

.menu:
        mov     byte [backToMenu], 1
        ret

.quit:
        mov     byte [quitGame], 1
        ret
endp

proc UpdateHighScore
        mov     eax, [score]
        cmp     eax, [bestScore]
        jbe     .done
        mov     [bestScore], eax
        mov     byte [newRecord], 1

.done:
        ret
endp

proc LoadHighScore
        mov     dword [bestScore], 0
        invoke  CreateFileA, addr saveFileName, GENERIC_READ, FILE_SHARE_READ, 0, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, 0
        cmp     rax, INVALID_HANDLE_VALUE
        je      .done
        mov     [fileHandle], rax
        invoke  ReadFile, [fileHandle], addr bestScore, 4, addr bytesDone, 0
        invoke  CloseHandle, [fileHandle]

.done:
        ret
endp

proc SaveHighScore
        invoke  CreateFileA, addr saveFileName, GENERIC_WRITE, 0, 0, CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL, 0
        cmp     rax, INVALID_HANDLE_VALUE
        je      .done
        mov     [fileHandle], rax
        invoke  WriteFile, [fileHandle], addr bestScore, 4, addr bytesDone, 0
        invoke  CloseHandle, [fileHandle]

.done:
        ret
endp

proc WriteCharAt uses rbx, xPos, yPos, chValue, colorValue
        mov     eax, dword [yPos]
        shl     eax, 16
        mov     ebx, dword [xPos]
        and     ebx, 0FFFFh
        or      eax, ebx

        invoke  SetConsoleCursorPosition, [hOut], eax
        invoke  SetConsoleTextAttribute, [hOut], dword [colorValue]

        mov     eax, dword [chValue]
        mov     [charBuffer], al
        invoke  WriteConsoleA, [hOut], addr charBuffer, 1, addr bytesDone, 0
        ret
endp

proc WriteStringAt uses rbx, xPos, yPos, textPtr, colorValue
        mov     eax, dword [yPos]
        shl     eax, 16
        mov     ebx, dword [xPos]
        and     ebx, 0FFFFh
        or      eax, ebx

        invoke  SetConsoleCursorPosition, [hOut], eax
        invoke  SetConsoleTextAttribute, [hOut], dword [colorValue]
        fastcall StrLen, qword [textPtr]
        invoke  WriteConsoleA, [hOut], qword [textPtr], eax, addr bytesDone, 0
        ret
endp

proc WriteUIntAt uses rbx rdi, xPos, yPos, value, colorValue
        lea     rdi, [numberBuffer + 15]
        mov     byte [rdi], 0
        mov     eax, dword [value]
        cmp     eax, 0
        jne     .digits

        dec     rdi
        mov     byte [rdi], '0'
        jmp     .write

.digits:
        mov     ebx, 10

.digitLoop:
        xor     edx, edx
        div     ebx
        add     dl, '0'
        dec     rdi
        mov     [rdi], dl
        test    eax, eax
        jne     .digitLoop

.write:
        fastcall WriteStringAt, dword [xPos], dword [yPos], rdi, dword [colorValue]
        ret
endp

proc StrLen uses rdi, textPtr
        mov     rdi, qword [textPtr]
        xor     eax, eax

.loop:
        cmp     byte [rdi + rax], 0
        je      .done
        inc     eax
        jmp     .loop

.done:
        ret
endp

section '.data' data readable writeable

appTitle db 'ASM Snake', 0
titleTagline db 'A Windows x64 console snake game written in assembly.', 0
optionEasy db '1 - Easy    slower pace, fewer obstacles', 0
optionNormal db '2 - Normal  balanced default', 0
optionHard db '3 - Hard    fast pace, dense obstacles', 0
optionQuit db 'Q - Quit', 0
menuHint db 'Press Enter for Normal.', 0
highScoreLabel db 'Best score:', 0

scoreLabel db 'Score:', 0
bestLabel db 'Best:', 0
levelLabel db 'Level:', 0
lengthLabel db 'Length:', 0
foodLegendTitle db 'Food', 0
foodLegendApple db '*  +10 grow', 0
foodLegendBonus db '$  +30 grow x2', 0
foodLegendSlow db '+  +15 slower', 0
foodLegendRush db '!  +20 faster', 0
foodLegendTrim db '-  +5 trim tail', 0
controlsTitle db 'Controls', 0
controlsMove db 'WASD / arrows move', 0
controlsPause db 'P pause', 0
controlsRestart db 'R restart', 0
controlsMenu db 'M menu', 0
controlsQuit db 'Q / Esc quit', 0

pauseText db 'PAUSED', 0
gameOverText db 'GAME OVER', 0
finalScoreText db 'Final score:', 0
newRecordText db 'New high score!', 0
gameOverPrompt db 'Enter/R restart, M menu, Q quit', 0

saveFileName db 'asm-snake.sav', 0
blankLine db 100 dup(' '), 0
hudBlank db 40 dup(' '), 0

cursorInfo dd 1, 0

hOut dq 0
fileHandle dq 0
bytesDone dd 0

rngState dd 0
score dd 0
bestScore dd 0
level dd 1
speedMod dd 0
tickDelay dd 115
snakeLen dd 5
obstacleCount dd 0
obstacleTarget dd 14
growAmount dd 0

difficulty db 2
direction db DIR_RIGHT
nextDirection db DIR_RIGHT
paused db 0
gameOver db 0
quitGame db 0
backToMenu db 0
restartGame db 0
newRecord db 0
ateFood db 0

newX db 0
newY db 0
tempX db 0
tempY db 0
foodX db 0
foodY db 0
foodKind db FOOD_APPLE
cellChar db ' '
cellColor dd COLOR_DEFAULT
charBuffer db ' '
numberBuffer rb 16

drawX dd 0
drawY dd 0

snakeX rb MAX_CELLS
snakeY rb MAX_CELLS
obstacleX rb MAX_OBSTACLES
obstacleY rb MAX_OBSTACLES

section '.idata' import data readable writeable

library kernel32, 'KERNEL32.DLL', \
        user32, 'USER32.DLL'

include 'api\kernel32.inc'
include 'api\user32.inc'
