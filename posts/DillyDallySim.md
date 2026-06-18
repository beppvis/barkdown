---
title: Dilly Dally Simulator
slug: dilly-dally-sim 
description: A multiplayer RTS game
author: John Smith
image: xxx.png
created: 2026-06-17
read_time: xx mins
style: static/tufte.css
---


10, Jun 2026
## Networking
here is what I am thinking for a game networks server Player sends a join request , server in turn accept/decline ,if accepted then it will send a message with a UID for that player. Then after this the server will now send the players inside the game player_info containing {Player_id, player_position} so a player recieving this, check if it has the given player_id in its local game . if not it will create a player and put it in its position. Now if a player exists, then it interpolates between old and new positions. if player disconnects, then the server is send the message dissconnect player , and then with the player id.

## Problems
I want to send all of this as byte, but then how would I diffenritae between things. I got the idea from [tigerbeetle](https:www.tigerbeetle.com) to do this.
