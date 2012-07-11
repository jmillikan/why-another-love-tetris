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

   game_paused = false

   drop_timeout = 0.05
   piece_timeout = 2
   til_next_piece = piece_timeout
   piece = nil
   piecex = 0
   piecey = 0 
end

function love.update(delta)
   if game_paused then return end

   if piece then
      til_next_drop = til_next_drop - delta
      
      if til_next_drop <= 0 then
	 til_next_drop = til_next_drop + drop_timeout

	 if piece_bonks() then
	    for y,row in ipairs(piece) do
	       for x,i in ipairs(row) do
		  if piece[y][x] == 1 then
		     playfield[piecey + (y - 1)][piecex + (x - 1)] = 1
		  end
	       end
	    end

	    piece = nil
	 else
	    piecey = piecey + 1
	 end
	 
	 -- nil out piece if done...
	 
      end
   else
      til_next_piece = til_next_piece - delta
      if til_next_piece <= 0 then
	 til_next_piece = piece_timeout
	 -- TODO: Spawn block...
	 
	 -- Heh heh
	 piece = {{1,0,0,0},{1,0,0,0},{1,0,0,0},{1,0,0,0}}
	 piecex = playfield_width / 2
	 piecey = 1

	 piece_on_screen = true
	 til_next_drop = drop_timeout
      end
   end
end

function piece_bonks()
   for y,row in ipairs(piece) do
      for x,v in ipairs(row) do
	 -- below playing field?
	 if piece[y][x] == 1 then
	    if piecey + (y - 1) + 1 > playfield_height then
	       return true
	    end

	    if playfield[piecey + (y - 1) + 1][piecex + (x - 1)] == 1 then
	       return true
	    end
	 end
      end
   end
end

function love.draw()
   if game_paused then
      love.graphics.print("Paused", 400, 300)
   end

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
      for y,row in ipairs(piece) do
	 for x,v in ipairs(row) do
	    if v == 1 then
	       draw_block(piecex + (x - 1), piecey + (y - 1))
	    end
	 end
      end
   end
end

function draw_block(x, y)
   love.graphics.rectangle("line", (x - 1) * block_width + playfield_screenx, (y - 1) * block_height + playfield_screeny, block_width, block_height)
end
