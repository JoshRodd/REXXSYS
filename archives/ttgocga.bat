/* */
'mode co40'
who = arg()
if who = 0 then color = 9
else color = 2
call clrscrn
do forever
call seek   'screen', 0
call write 'screen', 'Pick level of play. 0 = easy.', 14
call seek   'screen', 80
call write 'screen', '1 = try a bit. 2 = play best', 14
level = read('keyboard')
if level <> '0' & level <> '1' & level <> '2' then do
   call seek 'screen', 160
   call write 'screen', level 'is not a valid reply.', 12
   call seek 'screen', 240
   call write 'screen', 'You must say 0, 1, or 2.',12
   end
else leave
end
set.1.1 = 1
set.1.2 = 2
set.1.3 = 3
set.2.1 = 4
set.2.2 = 5
set.2.3 = 6
set.3.1 = 7
set.3.2 = 8
set.3.3 = 9
set.4.1 = 1
set.4.2 = 4
set.4.3 = 7
set.5.1 = 2
set.5.2 = 5
set.5.3 = 8
set.6.1 = 3
set.6.2 = 6
set.6.3 = 9
set.7.1 = 1
set.7.2 = 5
set.7.3 = 9
set.8.1 = 3
set.8.2 = 5
set.8.3 = 7
do forever /*  start: */
sq = 0
do i = 1 to 9
v.i = i
end
do forever  /* start1: */
  ok = 0
  call seek  'screen', 320
  call write 'screen', 'Choose x or o', 14
  you = translate(read('keyboard'))
  me = 'O'
  if you <> 'X' then do
    if you <> 'O' then do
     call clrscrn
     call write 'screen', ' You did not say X or O.', 12
     end
    else do
      ok = 1
      v.1 = 'X'
      me = 'X'
      sq = 1
      end
    end
  else ok = 1
if ok = 1 then leave
end  /* start 1 */
call clrscrn
call write 'screen', 'Pick your square for your', 14
call seek 'screen', 80
call write 'screen', 'next move by number.',14
do forever
   tst = me
   call test
call display
   if win = me then do
      call write 'screen', 'I win!', 12
      leave
      end
   if win = 'DRAW' then do
    call write 'screen', 'Game is a draw.', 14
    leave
      end
call write 'screen', ' Your move: ', 14
num = translate(read('keyboard'))
call clrscrn
if num >  0 & num <  10 & v.num = num then do
    call clrscrn
    call write 'screen', 'Thinking...', 11
    v.num = you
    sq = sq + 1
    tst = you
    call test
    if win = you then do
	call display
	call write 'screen', 'Congratulations! You win.', 10
	leave
	end
    if win = 'DRAW' then do
     call write 'screen', 'Game is a draw. Too bad.', 14
     leave
       end
    move = 0
/* first see if I can win*/
    do i = 1 to 8
       in = 0
       do j = 1 to 3
       index = set.i.j
       if v.index = me then in = in + 1
       if v.index = you then in = 0
       end
       if in = 2 then do j = 1 to 3
	index = set.i.j
	if v.index = index then move = index
	end
    end
    if move <> 0 then aa = 1
    else do
/* if level 0 , then just choose random here */
      if level = 0 then do until move <> 0
	 index = random(1,9)
	 if v.index = index then move = index
	 end
/* if O and center is free, take it */
      else if me = 'O' & v.5 = 5 &level = 2 then move = 5
      if move <> 0 then a = 1
      else do
/* now see if I have to defend against 2 in a row */
       do i = 1 to 8
	in = 0
	 do j = 1 to 3
	 index = set.i.j
	 if v.index = you then in = in + 1
	 end
	 if in = 2 then do j = 1 to 3
	    index = set.i.j
	    if v.index = index then move = index
	    end
       end
/* at this point opt out of level 1 */
       if level = 1 then do
	  do while move = 0
	   index = random(1,9)
	   if v.index = index then move = index
	   end
	  end
       if move <> 0 then a = 1
       else do
/* next just try for a corner if x, not a corner if o */
	if me = 'X' | v.5 = you then do
	 if v.9 = 9 then move = 9
	 if v.7 = 7 then move = 7
	 if v.3 = 3 then move = 3
	 if v.1 = 1 then move = 1
	 end
	else do
	 if v.8 = 8 then move = 8
	 if v.6 = 6 then move = 6
	 if v.9 = 9 then move = 9
	 if v.7 = 7 then move = 7
	 if v.3 = 3 then move = 3
	 if v.1 = 1 then move = 1
	 if v.4 = 4 & v.6 = 6 then move = 4
	 if v.2 = 2 & v.8 = 8 then move = 2
	 end
	 end
	 if move <> 0 then a = 1
/* finally take anything I can */
	 else do i = 1 to 9
	   if v.i = i & move = 0 then move = i
	   end
      end
      end
   v.move = me
   sq = sq + 1
end
else do
   call seek 'screen', 0
   call write 'screen',   num  'is not a valid move. try again', 12
   end
end
call seek 'screen', 1120
call write 'screen', 'Another game? (y or n)?', 14
ans = translate(read('keyboard'))
if substr(ans,1) <> 'Y' then leave
call clrscrn
end
'mode co80'
exit
test:
win = ' '
    do i = 1 to 8
    in = 0
     do j = 1 to 3
     index = set.i.j
     if v.index = tst then in = in + 1
     end
     if in = 3 then do
      win = tst
      leave
      end
    end
if sq = 9 &win = ' ' then do
    win = 'DRAW'
    end
return
display:
call clrscrn
do i = 1 to 9
a.i = 7
if v.i = me then a.i = 4
if v.i = you then a.i = color
end
scr1 = 170
do i = 1 to 9 by 3
scr = scr1 + 80
scr1 = scr
do j = 0 to 2
ii = i + j
call seek 'screen', scr
call write 'screen', v.ii, a.ii
if j <> 2 then do
   scr = scr + 3
   call seek 'screen', scr
   call write 'screen', '³', 14
   scr = scr + 3
   end
end
if i <> 7 then do
   scr = scr1 + 80
   scr1 = scr
   call seek 'screen', scr
   call write 'screen', 'ÄÄÄÅÄÄÄÄÄÅÄÄÄ', 14
   end
end
call seek 'screen', 730
return
clrscrn: 'cls'
call seek 'screen', 0
call write 'screen', '  '
call seek 'screen', 80
call write 'screen', '  '
call seek 'screen', 0
return
random: do forever
ran = time(s)
ran = substr(ran,length(ran),1)
if ran > 0 then return ran
end
/ mode co40 who arg 0 color 9 2 clrscrn seek screen write Pick level of play. 0 = easy. 14 80 1 = try a bit. 2 = play best level read keyboard 1 160 is not a valid reply. 12 240 You must say 0, 1, or 2. set.1.1 set.1.2 set.1.3 3 set.2.1 4 set.2.2 5 set.2.3 6 set.3.1 7 set.3.2 8 set.3.3 set.4.1 set.4.2 set.4.3 set.5.1 set.5.2 set.5.3 set.6.1 set.6.2 set.6.3 set.7.1 set.7.2 set.7.3 set.8.1 set.8.2 set.8.3 sq i v.i ok 320 Choose x or o you translate me O X  You did not say X or O. v.1 Pick your square for your next move by number. tst test display win I win! DRAW Game is a draw.  Your move:  num 10 v.num Thinking... 11 Congratulations! You win. Game is a draw. Too bad. move in j index set.i.j v.index aa random v.5 a v.9 v.7 v.3 v.8 v.6 v.4 v.2 v.move is not a valid move. try again 1120 Another game? (y or n)? ans substr Y mode co80   a.i scr1 170 scr ii v.ii a.ii ³ ÄÄÄÅÄÄÄÄÄÅÄÄÄ 730 cls    ran time s length      
             
     	        
                    &    +        2    +    8   V     &    +   Y     2    +    \   V   y               y        y        y      	       &    +        2    +    y       ©     &    +   ¬     2    +    °   ©      
       É     Ñ     Ù   á  ã   ë  í   õ  ÷   ÿ    	            %  ë  -  	 5    =  õ  E   M  á  U  ÿ  ]    e    m  õ  u    }  á    õ    	                                         &    +   ¡    2    +    ¥  V   ³   ·              Á   Ä    ³   Æ 	       ³   Ä 	            2    +    È  ©      
         á   Æ  Á   Æ             
             	               2    +    å  V     &    +   Y     2    +    ÿ  V           Á            %   Á 	       2    +    )  ©           %   0 	       2    +    5  V           2    +    E  V   R   ·                     R      R  V  Y   R 	            2    +    _  k Y   ³             ³        %   ³ 	           2    +    n  V          %   0 	       2    +      V         ¡              ¦       ©     á   «  ±   ¹   Á 	  ¦   ¦      ¹   ³ 	  ¦          ¦    	    ©     á   «  ±   ¹   « 	  ¡   «          ¡    	  Á     
       y     	      ¡     «   Ä           ¹   « 	  ¡   «     
    Á   Ä  Ë  õ    y     	  ¡  õ     ¡    	  Ï     
              ¦       ©     á   «  ±   ¹   ³ 	  ¦   ¦          ¦    	    ©     á   «  ±   ¹   « 	  ¡   «          y     	         ¡     «   Ä           ¹   « 	  ¡   «          ¡    	  Ï     
       Á   Æ  Ë   ³ 	      Ñ    	  ¡      Õ  	 	  ¡  	   Ù  á  	  ¡  á    á    	  ¡        
      Ý   	  ¡     á  ÿ  	  ¡  ÿ    Ñ    	  ¡      Õ  	 	  ¡  	   Ù  á  	  ¡  á    á    	  ¡      å  ë   á  ÿ  	  ¡  ë    é     Ý   	  ¡             ¡    	  Ï     
                   ¡    	  ¡             í   Á             
       &    +        2    +    R   ô  ©           &    +       2    +      V   0   ·                4   0        ; 	             =         %   G           ¦       ©     á   «  ±   ¹    	  ¦   ¦          ¦  á  	     %                      %   G 	     %   0                          I  	      Á 	 I  ë       ³ 	 I         M  R            á   V   M  Y   M   V    ©        Z      ©    &    +    V    2    +   ]  b    ©    	     V   V  á     &    +    V    2    +    g  V   V   V  á             	 	     V   M  Y   M   V    &    +    V    2    +    i  V           &    +   w          {    &    +        2    +        &    +   Y     2    +        &    +         Ä                      4                        	        ! gw 0