.PHONY: run
.ONESHELL:
.DELETE_ON_ERROR:

run: sdl RISC_OS ../Choices/Boot/Tasks/Pinboard
	RISC_OS_Alias_IXFSBoot='Dir $.dev.fd.4
	SetType !Boot.Choices.Boot.Tasks.Pinboard FEB
	IfThere !Boot.!Run Then /!Boot Else Desktop -file !Boot.Choices.Boot.Tasks.Pinboard' ./sdl ./RISC_OS --nvram CMOS 4<../..

sdl: sdlkey.h protocol.h
	g++ -pthread -O2 `sdl2-config --cflags --libs` --std=c++11 sdl.cpp -o sdl

sdlkey.h: sdlkey
	./sdlkey > sdlkey.h

sdlkey: sdlkey.c Keyboard.h
	gcc -std=gnu99 `sdl2-config --cflags` sdlkey.c -o sdlkey

../Choices/Boot/Tasks/Pinboard:
	set -e
	mkdir -p ../Choices/Boot/Tasks
	echo "X AddTinyDir IXFS::Root.\$$
	X AddTinyDir IXFS::Root.\$$.dev.fd.4
	X AddTinyDir IXFS::Root.\$$$$(echo $$HOME | tr ./ /.)
	" > $@
	
	
