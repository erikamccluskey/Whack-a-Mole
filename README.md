# Whack-a-Mole

Whack-a-mole

What is the game? 

The game I have created is simulating the game Whack-a-mole which is a popular carnival game. 
The goal of the game is press the buttons before the timer expires. Every level completed,
the timer reduces and the player must be faster and faster in order to win the game.

How do you play?

To play, simply press the reset button on the Nucleo board. The game will enter a mode where it is 
waiting for a player. To exit this mode, press any of the 4 coloured buttons. Once you press one of these
buttons, you will enter the game play. Simply press the button associated with each light before
the timer runs out. Each level will get more and more challenging. After completing 15 levels, you win.
If you lose, your score will flash in binary and the game will restart. To play again, press any of the 4 buttons.

Encountered problems.

The main problem I encountered through this project was actually that my code was too long. I was
unable to branch to the branch I wanted as it was too many bytes away. It took me a while to understand
how to solve this problem but the solution was simple. I added the directive 'LTORG' at the end
of each subroutine. This allowed my program to create space and keep track of the constants required if
they were too far away.

Features I succesfully implemented:
- waiting for a player indefinitely
- winning signal (all 4 lights flashing simultaneously)
- losing signal (number of levels completed flashing in binary)
    - if number is higher than 15, all lights will flash 
    - if number is less than 1, game starts over 
           - it is almost impossible to fail level 1 therefore I made the assumption
             that if a player completes 0 level, he was AFK (away from keyboard) and the
             game enters waitForPlayer mode

Possible improvements:

The method I am using to flash the losing levels in binary is quite inefficient. It is a lot of
code duplication. Perhaps if I had to re-do this project, I would try and find a better / more optimal
solution for this part of the program.

Adjusting game parameters

In order to change:
a) PrelimWait ->  Update the number on line 10
b) ReactTimer ->  Update the timer value on line 11
C) NumCycles  ->  Update the number of cycles in a game on line 12
d) WinningSignalTime ->  Update the timer value on line 13
   LosingSignalTime  ->  Update the timer value on line 20
