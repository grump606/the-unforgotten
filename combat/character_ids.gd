class_name CharacterIds
extends RefCounted
## The four playable characters' ids, so code never spells them out by hand (a typo in a bare &"theif" would
## silently match nothing). The ids are also the save format, file names and content keys: never change a value.

const DESERTER := &"deserter"
const THIEF := &"thief"
const MEDIUM := &"medium"
const STRAY := &"stray"
