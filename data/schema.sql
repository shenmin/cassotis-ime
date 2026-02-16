-- cassotis ime sqlite schema v1

CREATE TABLE IF NOT EXISTS meta (
    key TEXT PRIMARY KEY,
    value TEXT NOT NULL
);

INSERT OR IGNORE INTO meta(key, value) VALUES('schema_version', '1');

CREATE TABLE IF NOT EXISTS dict_base (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    pinyin TEXT NOT NULL,
    text TEXT NOT NULL,
    weight INTEGER DEFAULT 0,
    comment TEXT DEFAULT ''
);

CREATE INDEX IF NOT EXISTS idx_dict_base_pinyin ON dict_base(pinyin);

CREATE TABLE IF NOT EXISTS dict_user (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    pinyin TEXT NOT NULL,
    text TEXT NOT NULL,
    weight INTEGER DEFAULT 0,
    last_used INTEGER DEFAULT 0,
    UNIQUE(pinyin, text)
);

CREATE INDEX IF NOT EXISTS idx_dict_user_pinyin ON dict_user(pinyin);
