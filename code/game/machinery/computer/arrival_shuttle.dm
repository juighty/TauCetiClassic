#define ARRIVAL_SHUTTLE_MOVE_TIME 175
#define ARRIVAL_SHUTTLE_COOLDOWN 650


var/location = 0 // 0 - Start 2 - NSS Exodus 1 - transit
var/moving = 0
var/area/curr_location
var/lastMove = 0

/obj/machinery/computer/arrival_shuttle
	name = "Arrival Shuttle Console"
	icon = 'icons/obj/computer.dmi'
	icon_state = "wagon"
	var/arrival_note = "Arrival shuttle docked with the NSS Exodus."
	var/department_note = "Arrival shuttle left the NSS Exodus."
	var/obj/item/device/radio/intercom/radio


/obj/machinery/computer/arrival_shuttle/atom_init()
//	curr_location= locate(/area/shuttle/arrival/pre_game)
	radio = new (src)
	. = ..()

/obj/machinery/computer/arrival_shuttle/proc/try_move_from_station()
	if(moving || location != 2 || !SSshuttle)
		return
	var/myArea = get_area(src)
	if(SSshuttle.forbidden_atoms_check(myArea))
		addtimer(CALLBACK(src, .proc/try_move_from_station), 600)
		return
	arrival_shuttle_move()

/obj/machinery/computer/arrival_shuttle/proc/arrival_shuttle_ready_move()
	if(lastMove + ARRIVAL_SHUTTLE_COOLDOWN > world.time)
		return FALSE
	return TRUE

/obj/machinery/computer/arrival_shuttle/proc/arrival_shuttle_move()
	set waitfor = 0
	if(moving)
		return
	if(!arrival_shuttle_ready_move())
		return
	moving = 1
	lastMove = world.time
	var/area/fromArea
	var/area/toArea
	var/area/destArea
	var/destLocation

	if(location == 0)
		fromArea = locate(/area/shuttle/arrival/pre_game)
		destArea = locate(/area/shuttle/arrival/station)
		destLocation = 2
	else if(location == 2)
		fromArea = locate(/area/shuttle/arrival/station)
		destArea = locate(/area/shuttle/arrival/pre_game)
		destLocation = 0
	else
		return

	toArea = locate(/area/shuttle/arrival/transit)
	curr_location = fromArea

	for(var/obj/machinery/light/small/L in fromArea)
		L.brightness_color = "#00ff00"
		L.color = "#00ff00"
		L.update(0)

	sleep(140)

	lock_doors(fromArea)

	sleep(10)

	for(var/obj/machinery/light/small/L in fromArea)
		L.brightness_color = initial(L.brightness_color)
		L.color = initial(L.color)
		L.update(0)

	sleep(50)

	toArea.parallax_movedir = WEST
	fromArea.move_contents_to(toArea, null, WEST)
	location = 1
	shake_mobs(toArea)

	curr_location = toArea
	fromArea = toArea
	toArea = destArea

	sleep(ARRIVAL_SHUTTLE_MOVE_TIME)
	curr_location.parallax_slowdown()
	sleep(PARALLAX_LOOP_TIME)

	fromArea.move_contents_to(toArea, null, WEST)
	radio.autosay(arrival_note, "Arrivals Alert System")

	location = destLocation
	shake_mobs(toArea)

	curr_location = destArea
	moving = 0
	open_doors(toArea, location)

	if(location == 2)
		addtimer(CALLBACK(src, .proc/try_move_from_station), 600)


/obj/machinery/computer/arrival_shuttle/proc/lock_doors(area/A)
	SSshuttle.undock_act(/area/centcom/arrival, "velocity_1")
	SSshuttle.undock_act(/area/hallway/secondary/entry, "arrival_1")
	SSshuttle.undock_act(A)

/obj/machinery/computer/arrival_shuttle/proc/open_doors(area/A, arrival)
	switch(arrival)
		if(0) //Velocity
			SSshuttle.dock_act(/area/centcom/arrival, "velocity_1")
			SSshuttle.dock_act(A)

		if(2) //Station
			SSshuttle.dock_act(/area/hallway/secondary/entry, "arrival_1")
			SSshuttle.dock_act(A)

/obj/machinery/computer/arrival_shuttle/proc/shake_mobs(area/A)
	for(var/mob/M in A)
		if(M.client)
			if(location == 1)
				if(M.ear_deaf <= 0 || istype(M, /mob/dead/observer))
					M << sound('sound/effects/shuttle_flying.ogg')
			spawn(0)
				if(M.buckled)
					shake_camera(M, 2, 1)
				else
					shake_camera(M, 4, 2)
					M.Weaken(4)
		if(isliving(M) && !M.buckled)
			var/mob/living/L = M
			if(isturf(L.loc))
				for(var/i=0, i < 5, i++)
					var/turf/T = L.loc
					var/hit = 0
					T = get_step(T, EAST)
					if(T.density)
						hit = 1
						if(i > 1)
							L.adjustBruteLoss(10)
						break
					else
						for(var/atom/movable/AM in T.contents)
							if(AM.density)
								hit = 1
								if(i > 1)
									L.adjustBruteLoss(10)
									if(isliving(AM))
										var/mob/living/bumped = AM
										bumped.adjustBruteLoss(10)
								break
					if(hit)
						break
					step(L, EAST)

/obj/machinery/computer/arrival_shuttle/ui_interact(user)
	var/dat = "<center>Shuttle location:[curr_location]<br>Ready to move[!arrival_shuttle_ready_move() ? " in [max(round((lastMove + ARRIVAL_SHUTTLE_COOLDOWN - world.time) * 0.1), 0)] seconds" : ": now"]<br><b><A href='?src=\ref[src];move=1'>Send</A></b></center><br>"
	user << browse("[entity_ja(dat)]", "window=researchshuttle;size=200x100")

/obj/machinery/computer/arrival_shuttle/Topic(href, href_list)
	. = ..()
	if(!.)
		return

	if(href_list["move"])
		if(!arrival_shuttle_ready_move())
			to_chat(usr, "<span class='notice'>Shuttle is not ready to move yet.</span>")
		else if(!moving && location == 0)
			to_chat(usr, "<span class='notice'>Shuttle recieved message and will be sent shortly.</span>")
			arrival_shuttle_move()
		else
			to_chat(usr, "<span class='notice'>Shuttle is already moving or docked with station.</span>")

/obj/machinery/computer/arrival_shuttle/dock
	name = "Arrival Shuttle Communication Console"
	icon = 'icons/obj/computer.dmi'
	icon_state = "wagon"

/obj/machinery/computer/arrival_shuttle/dock/ui_interact(user)
	var/dat1 = "<center>Shuttle location:[curr_location]<br>Ready to move[!arrival_shuttle_ready_move() ? " in [max(round((lastMove + ARRIVAL_SHUTTLE_COOLDOWN - world.time) * 0.1), 0)] seconds" : ": now"]<br><b><A href='?src=\ref[src];back=1'>Send back</A></b></center><br>"
	user << browse("[entity_ja(dat1)]", "window=researchshuttle;size=200x100")

/obj/machinery/computer/arrival_shuttle/dock/Topic(href, href_list)
	. = ..()
	if(!.)
		return

	if(href_list["back"])
		if(!arrival_shuttle_ready_move())
			to_chat(usr, "<span class='notice'>Shuttle is not ready to move yet.</span>")
		else if(!moving && location == 2)
			to_chat(usr, "<span class='notice'>Shuttle recieved message and will be sent shortly.</span>")
			arrival_shuttle_move()
		else
			to_chat(usr, "<span class='notice'>Shuttle is already moving or docked with station.</span>")
