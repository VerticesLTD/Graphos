# This script is meant for future use.
# When the buttons textures will have a filled inside, we can use this script
# to make sure clicks are only registered when done directly on the image,
# rather then inside the button rectangle but not on the image.
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
