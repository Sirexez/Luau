
local board = {
    {' ', ' ', ' '},
    {' ', ' ', ' '},
    {' ', ' ', ' '}
}

function printBoard()
    print("\n  1   2   3")
    for i = 1, 3 do
        io.write(i .. " ")
        for j = 1, 3 do
            io.write(board[i][j])
            if j < 3 then io.write(" | ") end
        end
        print()
        if i < 3 then print("  ---------") end
    end
    print()
end

function checkWinner(player)
    for i = 1, 3 do
        if board[i][1] == player and board[i][2] == player and board[i][3] == player then return true end
        if board[1][i] == player and board[2][i] == player and board[3][i] == player then return true end
    end
    if board[1][1] == player and board[2][2] == player and board[3][3] == player then return true end
    if board[1][3] == player and board[2][2] == player and board[3][1] == player then return true end

    return false
end

function isDraw()
    for i = 1, 3 do
        for j = 1, 3 do
            if board[i][j] == ' ' then return false end
        end
    end
    return true
end

local currentPlayer = 'X'

while true do
    printBoard()
    print("Player " .. currentPlayer .. ", enter your move (row and column): ")
    io.write("Row (1-3): ")
    local row = tonumber(io.read())
    io.write("Col (1-3): ")
    local col = tonumber(io.read())

    if row >= 1 and row <= 3 and col >= 1 and col <= 3 and board[row][col] == ' ' then
        board[row][col] = currentPlayer
        if checkWinner(currentPlayer) then
            printBoard()
            print("Player " .. currentPlayer .. " wins")
            break
        elseif isDraw() then
            printBoard()
            print("It's a draw")
            break
        end
        currentPlayer = (currentPlayer == 'X') and 'O' or 'X'
    else
        print("Invalid move")
    end
end

