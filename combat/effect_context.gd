class_name EffectContext
extends RefCounted
## Fight numbers an effect may read to work out its raw damage (see CardEffect.raw_damage). One
## small object so a new kind that needs another number adds a field here instead of a parameter
## on every caller (Combat, the drag preview, the bot policies).

## The attacker's current Block.
var block := 0
## The target's Haunt.
var haunt := 0
## Cards played this turn, counting the card being played.
var plays := 0
## Size of the Forgotten pile.
var forgotten := 0


static func make(source_block: int, target_haunt: int, plays_including_this: int, forgotten_count: int = 0) -> EffectContext:
	var ctx := EffectContext.new()
	ctx.block = source_block
	ctx.haunt = target_haunt
	ctx.plays = plays_including_this
	ctx.forgotten = forgotten_count
	return ctx
