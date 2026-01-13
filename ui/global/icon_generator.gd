class_name IconGenerator
extends RefCounted

const SIZE = 24 

## Generates a solid color square with a border
static func make_color_swatch(color: Color) -> Texture2D:
	var img = Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0)) # Transparent
	
	# Draw the square
	var rect = Rect2i(4, 4, SIZE-8, SIZE-8)
	img.fill_rect(rect, color)
	
	# Border (essential for White/Yellow visibility)
	_draw_hollow_rect(img, rect, Color(0.5, 0.5, 0.5, 1.0))
	
	return ImageTexture.create_from_image(img)

static func _draw_hollow_rect(img: Image, rect: Rect2i, color: Color):
	img.fill_rect(Rect2i(rect.position.x, rect.position.y, rect.size.x, 1), color)
	img.fill_rect(Rect2i(rect.position.x, rect.position.y + rect.size.y - 1, rect.size.x, 1), color)
	img.fill_rect(Rect2i(rect.position.x, rect.position.y, 1, rect.size.y), color)
	img.fill_rect(Rect2i(rect.position.x + rect.size.x - 1, rect.position.y, 1, rect.size.y), color)
