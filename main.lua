function love.load()
   -- game constants
   block_width = 12
   block_height = 12

   playfield_width, playfield_height = 12, 30
   
   playfield_screenx = 400 - playfield_width * block_width / 2
   playfield_screeny = 300 - playfield_height * block_height / 2

   -- game state
   playfield = {}

   for y=1,playfield_height do
      playfield[y] = {}

      for x=1,playfield_width do
	 playfield[y][x] = 0
      end
   end

   -- test dropping...
   for y=playfield_height - 4,playfield_height do
      for x=1,playfield_width - 1 do
	 playfield[y][x] = 1
      end
   end

   game_paused = false

   drop_timeout = 0.2
   piece_timeout = 2
   til_next_piece = piece_timeout
   til_next_drop = drop_timeout
   piece = nil
   piecex = 0
   piecey = 0 
   score = 0
end

function blank_piece()
   return {{0,0,0,0},{0,0,0,0},{0,0,0,0},{0,0,0,0}}
end

function random_piece()
   return {{1,0,0,0},{1,0,0,0},{1,0,0,0},{1,0,0,0}}
end

function love.keypressed(key, unicode)
   if piece then
      if key == "down" then
	 til_next_drop = drop_timeout

	 try_piece_drop()
      end

      if key == "left" then
	 try_piece_shift(-1)
      end

      if key == "right" then
	 try_piece_shift(1)
      end

      if key == "p" then
	 game_paused = not game_paused
      end

      if key == "z" then
	 try_rotate("left")
      end

      if key == "x" then
	 try_rotate("right")
      end
   end
end

-- Just realized I royally screwed up. Emacs got it right and I missed it despite basing the pieces on emacs...
function try_rotate(dir)
   local test_piece = blank_piece()

   for x,y in blocks(piece) do
      if dir == "left" then
	 test_piece[5-x][y] = 1
      else
	 test_piece[x][5-y] = 1
      end
   end

   if not piece_collides(test_piece, piecex, piecey) then
      piece = test_piece
   end
end

function try_piece_shift(dir)
   -- dir is just an integer...

   if not piece_collides(piece, piecex + dir, piecey) then
      piecex = piecex + dir
   end
end

-- drop is not quite the right word. Anytime the block is forced down by 1, either by player or timer.
function try_piece_drop()
   if piece_collides(piece, piecex, piecey+1) then
      for x,y in blocks(piece) do
	 playfield[piecey + (y - 1)][piecex + (x - 1)] = 1
      end

      piece = nil

      try_clearing_rows()
   else
      piecey = piecey + 1
   end
end

function try_clearing_rows()
   local rows_to_clear = {}
   local clear_row
   local cleared = 0

   for y=1,playfield_height do
      row = playfield[y]
      clear_row = true

      for x,v in ipairs(row) do
	 if v == 0 then clear_row = false end
      end
      
      if clear_row then
	 cleared = cleared + 1

	 -- Remove the row and shift it to the top.
	 table.remove(playfield, y)

	 for x,v in ipairs(row) do
	    row[x] = 0
	 end
	 
	 table.insert(playfield, 1, row)
      end
   end

   score = score + cleared ^ 2
end



-- the only real use cases here are  1 left, 1 up, 1 down, or rot left/right. 
function piece_collides(test_piece, test_x, test_y)
   for x,y in blocks(test_piece) do
      blockx, blocky = test_x + (x - 1), test_y + (y - 1)

      if blocky > playfield_height or blocky < 1 or
	 blockx > playfield_width or blockx < 1 or
	 playfield[blocky][blockx] == 1 then
	 return true
      end
   end

   return false
end

function love.update(delta)
   if game_paused then return end

   if piece then
      til_next_drop = til_next_drop - delta
      
      if til_next_drop <= 0 then
	 til_next_drop = til_next_drop + drop_timeout

	 try_piece_drop()
      end
   else
      til_next_piece = til_next_piece - delta
      if til_next_piece <= 0 then
	 til_next_piece = piece_timeout

	 -- TODO: Real block...
	 -- TODO: Check for collisions on the way in (so the game can end...)
	 piece = random_piece()
	 piecex = playfield_width / 2
	 piecey = 1

	 piece_on_screen = true
	 til_next_drop = drop_timeout
      end
   end
end

function love.draw()
   if game_paused then
      love.graphics.print("Paused", 400, 300)
   end

   love.graphics.print("Score: " .. tostring(score), playfield_screenx, playfield_screeny - 20)

   love.graphics.rectangle("line", playfield_screenx - 1, playfield_screeny - 1, playfield_width * block_width + 2, playfield_height * block_height + 2)

   -- grid is 10x25,10px/block, from 100, 100 to 199, 249
   -- 1 is at top left... row-major to bottom right
   for block_y=1,playfield_height do
      for block_x=1,playfield_width do
	 if playfield[block_y][block_x] == 1 then
	    draw_block(block_x, block_y)
	 end
      end
   end

   if piece then
      for x,y in blocks(piece) do
	 draw_block(piecex + (x - 1), piecey + (y - 1))
      end
   end
end

function draw_block(x, y)
   love.graphics.rectangle("line", (x - 1) * block_width + playfield_screenx, (y - 1) * block_height + playfield_screeny, block_width - 1, block_height - 1)
end

-- Inefficient, and only as the piece is when blocks is run...
function blocks(piece)
   local pairs = {}
   local index = 1

   for y,row in ipairs(piece) do
      for x,v in ipairs(row) do
	 if v == 1 then
	    table.insert(pairs, {x,y})
	 end
      end
   end

   return function() 
      if index <= #pairs then
	 index = index + 1
	 return pairs[index - 1][1], pairs[index - 1][2]
      else
	 return nil
      end
	  end
end
