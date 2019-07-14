
/obj/machinery/gibber
	name = "Gibber"
	desc = "The name isn't descriptive enough?"
	icon = 'icons/obj/kitchen.dmi'
	icon_state = "grinder"
	density = 1
	anchored = 1
	var/operating = 0 //Is it on?
	var/dirty = 0 // Does it need cleaning?
	var/gibtime = 40 // Time from starting until meat appears
	var/mob/living/occupant // Mob who has been put inside
	use_power = 1
	idle_power_usage = 2
	active_power_usage = 500

//auto-gibs anything that bumps into it
/obj/machinery/gibber/autogibber
	var/turf/input_plate

	New()
		..()
		spawn(5)
			for(var/i in cardinal)
				var/obj/machinery/mineral/input/input_obj = locate( /obj/machinery/mineral/input, get_step(src.loc, i) )
				if(input_obj)
					if(isturf(input_obj.loc))
						input_plate = input_obj.loc
						qdel(input_obj)
						break

			if(!input_plate)
				log_misc("a [src] didn't find an input plate.")
				return

	Bumped(var/atom/A)
		if(!input_plate) return

		if(ismob(A))
			var/mob/M = A

			if(M.loc == input_plate
			)
				M.loc = src
				M.gib()


/obj/machinery/gibber/New()
	..()
	src.overlays += image('icons/obj/kitchen.dmi', "grjam")

/obj/machinery/gibber/update_icon()
	overlays.Cut()
	if (dirty)
		src.overlays += image('icons/obj/kitchen.dmi', "grbloody")
	if(stat & (NOPOWER|BROKEN))
		return
	if (!occupant)
		src.overlays += image('icons/obj/kitchen.dmi', "grjam")
	else if (operating)
		src.overlays += image('icons/obj/kitchen.dmi', "gruse")
	else
		src.overlays += image('icons/obj/kitchen.dmi', "gridle")

/obj/machinery/gibber/relaymove(mob/user)
	if(user.is_mob_incapacitated(TRUE)) return
	go_out()


/obj/machinery/gibber/attack_hand(mob/user as mob)
	if(stat & (NOPOWER|BROKEN))
		return
	if(operating)
		to_chat(user, SPAN_DANGER("It's locked and running"))
		return
	else
		src.startgibbing(user)

/obj/machinery/gibber/attackby(obj/item/grab/G as obj, mob/user as mob)
	if(src.occupant)
		to_chat(user, SPAN_WARNING("The gibber is full, empty it first!"))
		return

	if( !(istype(G, /obj/item/grab)) )
		to_chat(user, SPAN_WARNING("This item is not suitable for the gibber!"))
		return

	if( !iscarbon(G.grabbed_thing) && !istype(G.grabbed_thing, /mob/living/simple_animal) )
		to_chat(user, SPAN_WARNING("This item is not suitable for the gibber!"))
		return
	if(istype(G.grabbed_thing, /mob/living/simple_animal/scp))
		var/mob/living/simple_animal/scp/scp = G.grabbed_thing
		scp.lash_out()
		to_chat(user, SPAN_WARNING("This item is not suitable for the gibber!"))
		return
	var/mob/living/M = G.grabbed_thing
	if(user.grab_level < GRAB_AGGRESSIVE)
		to_chat(user, SPAN_WARNING("You need a better grip to do that!"))
		return

	if(M.abiotic(1))
		to_chat(user, SPAN_WARNING("Subject may not have abiotic items on."))
		return

	user.visible_message(SPAN_DANGER("[user] starts to put [M] into the gibber!"))
	src.add_fingerprint(user)
	if(do_after(user, 30, INTERRUPT_ALL, BUSY_ICON_HOSTILE) && G && G.grabbed_thing && !occupant)
		user.visible_message(SPAN_DANGER("[user] stuffs [M] into the gibber!"))
		M.forceMove(src)
		occupant = M
		update_icon()

/obj/machinery/gibber/verb/eject()
	set category = "Object"
	set name = "Empty Gibber"
	set src in oview(1)

	if (usr.stat != 0)
		return
	src.go_out()
	add_fingerprint(usr)
	return

/obj/machinery/gibber/proc/go_out()
	if (!src.occupant)
		return
	for(var/obj/O in src)
		O.loc = src.loc
	if (src.occupant.client)
		src.occupant.client.eye = src.occupant.client.mob
		src.occupant.client.perspective = MOB_PERSPECTIVE
	src.occupant.loc = src.loc
	src.occupant = null
	update_icon()
	return


/obj/machinery/gibber/proc/startgibbing(mob/user as mob)
	if(src.operating)
		return
	if(!src.occupant)
		visible_message(SPAN_DANGER("You hear a loud metallic grinding sound."))
		return
	use_power(1000)
	visible_message(SPAN_DANGER("You hear a loud squelchy grinding sound."))
	src.operating = 1
	update_icon()

	var/totalslabs = 3
	var/obj/item/reagent_container/food/snacks/meat/allmeat[totalslabs]

	if( istype(src.occupant, /mob/living/carbon/human/) )
		var/sourcename = src.occupant.real_name
		var/sourcejob = src.occupant.job
		var/sourcenutriment = src.occupant.nutrition / 15
		var/sourcetotalreagents = src.occupant.reagents.total_volume

		for(var/i=1 to totalslabs)
			var/obj/item/reagent_container/food/snacks/meat/human/newmeat = new
			newmeat.name = sourcename + newmeat.name
			newmeat.subjectname = sourcename
			newmeat.subjectjob = sourcejob
			newmeat.reagents.add_reagent("nutriment", sourcenutriment / totalslabs) // Thehehe. Fat guys go first
			src.occupant.reagents.trans_to(newmeat, round (sourcetotalreagents / totalslabs, 1)) // Transfer all the reagents from the
			allmeat[i] = newmeat

		src.occupant.attack_log += "\[[time_stamp()]\] Was gibbed by <b>[user]/[user.ckey]</b>" //One shall not simply gib a mob unnoticed!
		user.attack_log += "\[[time_stamp()]\] Gibbed <b>[src.occupant]/[src.occupant.ckey]</b>"
		msg_admin_attack("[user.name] ([user.ckey]) gibbed [src.occupant] ([src.occupant.ckey]) (<A HREF='?_src_=admin_holder;adminplayerobservecoodjump=1;X=[user.x];Y=[user.y];Z=[user.z]'>JMP</a>)")

		src.occupant.death(1)
		src.occupant.ghostize()

	else if( istype(src.occupant, /mob/living/carbon/) || istype(src.occupant, /mob/living/simple_animal/ ) )

		var/sourcename = src.occupant.name
		var/sourcenutriment = src.occupant.nutrition / 15
		var/sourcetotalreagents = 0

		if(istype(src.occupant, /mob/living/carbon/Xenomorph) ) // why are you gibbing aliens? oh well
			totalslabs = 3
			sourcetotalreagents = src.occupant.reagents.total_volume
		else if( istype(src.occupant, /mob/living/simple_animal/cow) || istype(src.occupant, /mob/living/simple_animal/hostile/bear) )
			totalslabs = 2
		else
			totalslabs = 1
			sourcenutriment = src.occupant.nutrition / 30 // small animals don't have as much nutrition

		for(var/i=1 to totalslabs)
			var/obj/item/reagent_container/food/snacks/meat/newmeat = new
			newmeat.name = "[sourcename]-[newmeat.name]"

			newmeat.reagents.add_reagent("nutriment", sourcenutriment / totalslabs)

			// Transfer reagents from the old mob to the meat
			if( istype(src.occupant, /mob/living/carbon/) )
				src.occupant.reagents.trans_to(newmeat, round(sourcetotalreagents / totalslabs, 1))

			allmeat[i] = newmeat

		if(src.occupant.client) // Gibbed a cow with a client in it? log that shit
			src.occupant.attack_log += "\[[time_stamp()]\] Was gibbed by <b>[user]/[user.ckey]</b>"
			user.attack_log += "\[[time_stamp()]\] Gibbed <b>[src.occupant]/[src.occupant.ckey]</b>"
			msg_admin_attack("\[[time_stamp()]\] <b>[key_name(user)]</b> gibbed <b>[key_name(src.occupant)]</b>")

		src.occupant.death(1)
		src.occupant.ghostize()

	qdel(occupant)
	occupant = null

	spawn(src.gibtime)
		playsound(src.loc, 'sound/effects/splat.ogg', 25, 1)
		operating = 0
		for (var/i=1 to totalslabs)
			var/obj/item/meatslab = allmeat[i]
			var/turf/Tx = locate(src.x - i, src.y, src.z)
			meatslab.loc = src.loc
			meatslab.throw_at(Tx,i,3,src)
			if (!Tx.density)
				new /obj/effect/decal/cleanable/blood/gibs(Tx,i)
		src.operating = 0
		update_icon()


