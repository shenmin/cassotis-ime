-- cassotis ime sqlite schema v5

CREATE TABLE IF NOT EXISTS meta (
    key TEXT PRIMARY KEY,
    value TEXT NOT NULL
);

INSERT OR IGNORE INTO meta(key, value) VALUES('schema_version', '5');

CREATE TABLE IF NOT EXISTS dict_base (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    pinyin TEXT NOT NULL,
    text TEXT NOT NULL,
    weight INTEGER DEFAULT 0,
    comment TEXT DEFAULT ''
);

CREATE INDEX IF NOT EXISTS idx_dict_base_pinyin ON dict_base(pinyin);

CREATE TABLE IF NOT EXISTS dict_jianpin (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    word_id INTEGER NOT NULL,
    jianpin TEXT NOT NULL,
    weight INTEGER DEFAULT 0,
    UNIQUE(word_id, jianpin),
    FOREIGN KEY(word_id) REFERENCES dict_base(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_dict_jianpin_key ON dict_jianpin(jianpin);

CREATE TABLE IF NOT EXISTS dict_user (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    pinyin TEXT NOT NULL,
    text TEXT NOT NULL,
    weight INTEGER DEFAULT 0,
    last_used INTEGER DEFAULT 0,
    UNIQUE(pinyin, text)
);

CREATE INDEX IF NOT EXISTS idx_dict_user_pinyin ON dict_user(pinyin);

CREATE TABLE IF NOT EXISTS dict_user_stats (
    pinyin TEXT NOT NULL,
    text TEXT NOT NULL,
    commit_count INTEGER DEFAULT 0,
    last_used INTEGER DEFAULT 0,
    PRIMARY KEY(pinyin, text)
);

CREATE INDEX IF NOT EXISTS idx_dict_user_stats_pinyin ON dict_user_stats(pinyin);

CREATE TABLE IF NOT EXISTS dict_user_penalty (
    pinyin TEXT NOT NULL,
    text TEXT NOT NULL,
    penalty INTEGER DEFAULT 0,
    last_used INTEGER DEFAULT 0,
    PRIMARY KEY(pinyin, text)
);

CREATE INDEX IF NOT EXISTS idx_dict_user_penalty_pinyin ON dict_user_penalty(pinyin);

CREATE TABLE IF NOT EXISTS dict_user_bigram (
    left_text TEXT NOT NULL,
    text TEXT NOT NULL,
    commit_count INTEGER DEFAULT 0,
    last_used INTEGER DEFAULT 0,
    PRIMARY KEY(left_text, text)
);

CREATE INDEX IF NOT EXISTS idx_dict_user_bigram_left_text ON dict_user_bigram(left_text);
