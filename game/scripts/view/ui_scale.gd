class_name UiScale
extends RefCounted

## HUD scaling policy for the real game window.
##
## `canvas_items` stretch alone scales the whole canvas by window_height / 720,
## so a 1080p monitor used to render every panel and button 1.5x larger while
## the sidebar kept eating the same share of the width. A bigger screen has to
## buy more visible map, not bigger buttons.
##
## The HUD therefore absorbs only a fraction of the extra height. The remainder
## becomes logical viewport space, which the camera's fit already spends on the
## map. Below the base height nothing is overridden: shrinking further would
## make the text unreadable.

const BASE_HEIGHT: float = 720.0
## Share of the extra height that the HUD is allowed to grow by. 0.0 would pin
## the HUD to base pixels and turn a 4K screen into unreadably small text.
const GROWTH: float = 0.45
const MAX_FACTOR: float = 1.9


## Total canvas scale the HUD should be drawn at for this window height.
static func target_factor(window_height: float) -> float:
	var natural: float = natural_factor(window_height)
	if natural <= 1.0:
		return natural
	return minf(1.0 + (natural - 1.0) * GROWTH, MAX_FACTOR)


## Scale the engine applies from the stretch settings alone.
static func natural_factor(window_height: float) -> float:
	return maxf(window_height, 1.0) / BASE_HEIGHT


## Multiplier to hand to `Window.content_scale_factor`, which stacks on top of
## the stretch scale.
static func content_scale_factor(window_height: float) -> float:
	var natural: float = natural_factor(window_height)
	if natural <= 0.0:
		return 1.0
	return target_factor(window_height) / natural


## Logical viewport height the window ends up with. The width follows the
## window's aspect, so a wider monitor also gains logical width.
static func logical_height(window_height: float) -> float:
	return maxf(window_height, 1.0) / maxf(target_factor(window_height), 0.001)


static func apply(window: Window) -> void:
	if window == null:
		return
	var factor: float = content_scale_factor(float(window.size.y))
	if not is_equal_approx(window.content_scale_factor, factor):
		window.content_scale_factor = factor
