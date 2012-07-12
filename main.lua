function love.load()
   math.randomseed(os.time())

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

   game_paused = false

   game_state = "unstarted"

   drop_timeout = 0.3
   piece_timeout = 2
--   drop_timeout = 0.05
--   piece_timeout = 0.05
   score = 0
end

function start_game()
   for y=1,playfield_height do
      playfield[y] = {}

      for x=1,playfield_width do
	 playfield[y][x] = 0
      end
   end

   piece = nil
   til_next_piece = piece_timeout
   score = 0
   
   game_state = "running"
end

all_pieces = {
   {{0,0,0},{1,1,1},{0,1,0}},
   {{0,1,0,0},{0,1,0,0},{0,1,0,0},{0,1,0,0}},
   {{0,1,0},{0,1,0},{0,1,1}},
   {{0,1,0},{0,1,0},{1,1,0}},
   {{0,1,0},{1,1,0},{1,0,0}},
   {{0,1,0},{0,1,1},{0,0,1}},
   {{1,1},{1,1}}
}


function random_piece()
   return all_pieces[math.random(#all_pieces)]
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

      if key == "z" then
	 try_rotate("left")
      end

      if key == "x" then
	 try_rotate("right")
      end

   end


   if key == "p" then
      game_paused = not game_paused
   end


   if key == "n" then
      if game_state ~= "running" or game_paused then
	 start_game()
      end
   end
end

-- I'm going to go ahead and start pretending this is SRS.
function try_rotate(dir)
   local test_piece = {}

   -- copy shape...
   for y,row in ipairs(piece) do
      test_piece[y] = {}
      for x,v in ipairs(row) do
	 test_piece[y][x] = 0
      end
   end
	 
   for x,y in blocks(piece) do
      if dir == "right" then
	 test_piece[(#piece + 1)-x][y] = 1
      else
	 test_piece[x][(#(piece[1]) + 1)-y] = 1
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

   if game_state ~= "running" then return end

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

	 if piece_collides(piece, piecex, piecey) then
	    game_state = "over"
	    return
	 end

	 piece_on_screen = true
	 til_next_drop = drop_timeout
      end
   end
end

function love.draw()
   if game_state == "over" then
      love.graphics.printf("Game Over", playfield_screenx, playfield_screeny - 20, playfield_width * block_width, "right")
   elseif game_paused then
      love.graphics.printf("Paused", playfield_screenx, playfield_screeny - 20, playfield_width * block_width, "right")
   end

   love.graphics.print("Score: " .. tostring(score), playfield_screenx, playfield_screeny - 20)

   love.graphics.rectangle("line", playfield_screenx - 1, playfield_screeny - 1, playfield_width * block_width + 2, playfield_height * block_height + 2)

   -- grid is 10x25,10px/block, from 100, 100 to 199, 249
   -- 1 is at top left... row-major to bottom right
   for x,y in blocks(playfield) do
      draw_block(x,y)
   end

   if piece then
      for x,y in blocks(piece) do
	 draw_block(piecex + (x - 1), piecey + (y - 1))
      end
   end
end

-- Well...
-- An image would probably be more appropriate, but this is supposed to be one file.
function draw_block(x, y)
   blockx = (x - 1) * block_width + playfield_screenx
   blocky = (y - 1) * block_height + playfield_screeny
   love.graphics.rectangle("line", blockx, blocky, block_width - 1, block_height - 1)
   love.graphics.line(blockx + 1, blocky + 1, blockx + block_width - 2, blocky + block_height - 2)
   love.graphics.line(blockx + block_width - 2, blocky + 1, blockx + 1, blocky + block_height - 2)
end

-- Inefficient, and only as the piece is when blocks is run...
-- Not exactly necessary, but removes 2 levels of nesting in 2 or 3 places.
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
