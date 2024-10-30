extends Node

var song_playing = null

func _play_sound(id):
	get_node(id).play()

func _stop_sound(id):
	get_node(id).stop()

func _play_music(id, delay = 0.0):
	if delay > 0.0: yield (get_tree().create_timer(delay), "timeout")
	
	if song_playing:
		var tween = get_tree().create_tween()
		tween.tween_property(song_playing, "volume_db", linear2db(0.01), 2.0)
		tween.tween_callback(song_playing, "stop")
		song_playing = null
		tween.tween_callback(self, "_play_music", [id])
		return 
	
	if not get_node(id): return 
	
	song_playing = get_node(id)
	song_playing.volume_db = linear2db(1.0)
	song_playing.play()

func _is_song_playing():
	if song_playing:
		return song_playing.playing
	else : return false
