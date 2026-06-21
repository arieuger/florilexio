extends RefCounted
class_name MinigameDifficulty

enum Level { EASY, MEDIUM, HARD, TUTORIAL }

static func get_id(level: int) -> StringName:
    match level:
        Level.EASY:
            return &"easy"
        Level.HARD:
            return &"hard"
        Level.TUTORIAL:
            return &"tutorial"
        _:
            return &"medium"