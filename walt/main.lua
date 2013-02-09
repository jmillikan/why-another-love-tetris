FAST = true

_ = require "underscore/underscore"
require "across_state_lines"

function dispatch(k,t)
   local a = t[k] or {_.identity}
   return (a[1])(unpack(_.slice(a,2,#a-1))) 
end

function love.load()
   math.randomseed(os.time())

   -- game constants
   block_width = 12
   block_height = 12

   playfield_width, playfield_height = 10,25
   
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

   drop_timeout = 0.3
   piece_timeout = 2

   if FAST then
      drop_timeout = 0.05
      piece_timeout = 0.05
   end

   score = 0

   ui = init_ui_graph(UI_STATES, 'unstarted')
end

game = {}

function game:from_unstarted()
   for y=1,playfield_height do
      playfield[y] = {}

      for x=1,playfield_width do
	 playfield[y][x] = 0
      end
   end

   piece = nil
   til_next_piece = piece_timeout
   score = 0
end

game.from_over = game.from_unstarted

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

function game:keypressed(key, unicode)
   if piece then
      dispatch(key, 
	 {
	    down = {function() til_next_drop = drop_timeout; try_piece_drop(); end},
	    left = {try_piece_shift, -1},
	    right = {try_piece_shift, 1},
	    z = {try_rotate, "left"},
	    x = {try_rotate, "right"}
	 })
   end

   if key == "p" then
      ui:change_ui_state('paused')
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

function game:update(delta)
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

	 piece = random_piece()
	 piecex = playfield_width / 2
	 piecey = 1

	 if piece_collides(piece, piecex, piecey) then
	    ui:change_ui_state('over')
	    return
	 end

	 piece_on_screen = true
	 til_next_drop = drop_timeout
      end
   end
end

function game:draw()
   love.graphics.print("Score: " .. tostring(score), playfield_screenx, playfield_screeny - 20)

   love.graphics.rectangle("line", playfield_screenx - 1, playfield_screeny - 1, playfield_width * block_width + 2, playfield_height * block_height + 2)

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

-- Removes 2 levels of nesting in a few places.
function blocks(piece)
   return coroutine.wrap(
      function() 
	 for y,row in ipairs(piece) do
	    for x,v in ipairs(row) do
	       if v == 1 then
		  coroutine.yield(x,y)
	       end
	    end
	 end
      end)
end


function state_thunk(s)
   return function()
      ui:change_ui_state(s)
      end
end

function keymap_method(map) 
   return function(s, key, unicode) 
      (map[key] or _.identity)()
	  end
end


UI_STATES = {
   unstarted = {
      draw = function() game:draw() end,
      keypressed = keymap_method({ n = state_thunk('running') }),
      to = { 'running' }
   },
   running = _.extend(game, { to = { 'over', 'paused' } }),
   paused = {
      to = { 'running' },
      draw = function()
	 love.graphics.print("Paused", playfield_screenx, playfield_screeny - 40)
	 game:draw()
      end,
      keypressed = keymap_method({ p = state_thunk('running') })
   },
   over = {
      draw = function()
	 love.graphics.print("Game Over", playfield_screenx, playfield_screeny - 40)
	 game:draw()
      end,
      keypressed = keymap_method({ n = state_thunk('running') }),
      to = { 'running' }
   }
}