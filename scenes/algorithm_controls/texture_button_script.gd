"""
This script calculates a bit mask for the buttons based on the alpha values of the shape.
This basically makes sure that clicks only register if they happen on the image, rather than
on the rectangular 'hitbox' of the button.
"""

extends TextureButton

const ALPHA_THRESHOLD: float = 0.1

func _ready() -> void:
	_set_click_mask_from_texture()

func _set_click_mask_from_texture() -> void:
	if texture_normal == null:
		return

	# image data
	var image: Image = texture_normal.get_image()
	
	# bitmap based on image transparency
	var bitmap: BitMap = BitMap.new()
	bitmap.create_from_image_alpha(image, ALPHA_THRESHOLD)
	
	# Result: Click only takes effect when clicking the actual image
	texture_click_mask = bitmap
