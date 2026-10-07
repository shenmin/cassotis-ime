-- cassotis ime sqlite schema v24

CREATE TABLE IF NOT EXISTS meta (
    key TEXT PRIMARY KEY,
    value TEXT NOT NULL
);

INSERT OR IGNORE INTO meta(key, value) VALUES('schema_version', '24');

CREATE TABLE IF NOT EXISTS dict_base (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    pinyin TEXT NOT NULL,
    text TEXT NOT NULL,
    weight INTEGER DEFAULT 0,
    comment TEXT DEFAULT '',
    contains_popularity_eligible INTEGER NOT NULL DEFAULT 1
);

CREATE INDEX IF NOT EXISTS idx_dict_base_pinyin ON dict_base(pinyin);
CREATE INDEX IF NOT EXISTS idx_dict_base_pinyin_weight ON dict_base(pinyin, weight);
CREATE INDEX IF NOT EXISTS idx_dict_base_text_weight ON dict_base(text, weight);

CREATE TABLE IF NOT EXISTS dict_base_completion_prior (
    pinyin TEXT NOT NULL,
    text TEXT NOT NULL,
    popularity_prior INTEGER NOT NULL DEFAULT 0,
    corpus_score INTEGER NOT NULL DEFAULT 0,
    document_score INTEGER NOT NULL DEFAULT 0,
    source_count INTEGER NOT NULL DEFAULT 0,
    path_score INTEGER NOT NULL DEFAULT 0,
    vertical_penalty INTEGER NOT NULL DEFAULT 0,
    layer_kind INTEGER NOT NULL DEFAULT 0,
    PRIMARY KEY(pinyin, text)
) WITHOUT ROWID;

CREATE INDEX IF NOT EXISTS idx_dict_base_completion_prior_pinyin
    ON dict_base_completion_prior(pinyin, popularity_prior DESC);

CREATE TABLE IF NOT EXISTS dict_base_completion_lookup (
    typed_prefix TEXT NOT NULL,
    full_pinyin TEXT NOT NULL,
    text TEXT NOT NULL,
    weight INTEGER NOT NULL DEFAULT 0,
    popularity_prior INTEGER NOT NULL DEFAULT 0,
    corpus_score INTEGER NOT NULL DEFAULT 0,
    document_score INTEGER NOT NULL DEFAULT 0,
    source_count INTEGER NOT NULL DEFAULT 0,
    path_score INTEGER NOT NULL DEFAULT 0,
    vertical_penalty INTEGER NOT NULL DEFAULT 0,
    layer_kind INTEGER NOT NULL DEFAULT 0,
    prefix_anchored INTEGER NOT NULL DEFAULT 0,
    rank_order INTEGER NOT NULL DEFAULT 0,
    PRIMARY KEY(typed_prefix, full_pinyin, text)
) WITHOUT ROWID;

CREATE INDEX IF NOT EXISTS idx_dict_base_completion_lookup_prefix
    ON dict_base_completion_lookup(typed_prefix, rank_order);

CREATE TABLE IF NOT EXISTS dict_base_completion_competition (
    context_width INTEGER NOT NULL,
    context_suffix TEXT NOT NULL,
    typed_prefix TEXT NOT NULL,
    full_pinyin TEXT NOT NULL,
    text TEXT NOT NULL,
    evidence_score INTEGER NOT NULL DEFAULT 0,
    occurrence_count INTEGER NOT NULL DEFAULT 0,
    source_count INTEGER NOT NULL DEFAULT 0,
    PRIMARY KEY(context_width, context_suffix, typed_prefix, full_pinyin, text)
) WITHOUT ROWID;

CREATE INDEX IF NOT EXISTS idx_dict_base_completion_competition_query
    ON dict_base_completion_competition(
        typed_prefix, context_width, context_suffix, evidence_score DESC);

CREATE TABLE IF NOT EXISTS dict_base_completion_pair_audit (
    context_width INTEGER NOT NULL,
    context_suffix TEXT NOT NULL,
    typed_prefix TEXT NOT NULL,
    baseline_full_pinyin TEXT NOT NULL,
    baseline_text TEXT NOT NULL,
    challenger_full_pinyin TEXT NOT NULL,
    challenger_text TEXT NOT NULL,
    decision INTEGER NOT NULL DEFAULT 0,
    keep_count INTEGER NOT NULL DEFAULT 0,
    switch_count INTEGER NOT NULL DEFAULT 0,
    keep_source_count INTEGER NOT NULL DEFAULT 0,
    switch_source_count INTEGER NOT NULL DEFAULT 0,
    confidence_milli INTEGER NOT NULL DEFAULT 0,
    PRIMARY KEY(context_width, context_suffix, typed_prefix,
        baseline_full_pinyin, baseline_text,
        challenger_full_pinyin, challenger_text)
) WITHOUT ROWID;

CREATE INDEX IF NOT EXISTS idx_dict_base_completion_pair_audit_query
    ON dict_base_completion_pair_audit(
        typed_prefix, baseline_full_pinyin, baseline_text,
        challenger_full_pinyin, challenger_text,
        context_width DESC, context_suffix);

CREATE TABLE IF NOT EXISTS dict_base_short_promotion (
    pinyin TEXT NOT NULL,
    baseline_text TEXT NOT NULL,
    promoted_text TEXT NOT NULL,
    lead INTEGER NOT NULL DEFAULT 0,
    candidates TEXT NOT NULL DEFAULT '',
    PRIMARY KEY(pinyin, baseline_text)
) WITHOUT ROWID;

CREATE TABLE IF NOT EXISTS dict_base_pinyin_alias (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    compact_pinyin TEXT NOT NULL,
    word_id INTEGER NOT NULL,
    UNIQUE(compact_pinyin, word_id),
    FOREIGN KEY(word_id) REFERENCES dict_base(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_dict_base_pinyin_alias_compact
    ON dict_base_pinyin_alias(compact_pinyin);

CREATE TABLE IF NOT EXISTS dict_jianpin (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    word_id INTEGER NOT NULL,
    jianpin TEXT NOT NULL,
    weight INTEGER DEFAULT 0,
    UNIQUE(word_id, jianpin),
    FOREIGN KEY(word_id) REFERENCES dict_base(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_dict_jianpin_key ON dict_jianpin(jianpin);
CREATE INDEX IF NOT EXISTS idx_dict_jianpin_key_weight_word ON dict_jianpin(jianpin, weight DESC, word_id);

CREATE TABLE IF NOT EXISTS dict_user (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    pinyin TEXT NOT NULL,
    text TEXT NOT NULL,
    weight INTEGER DEFAULT 0,
    last_used INTEGER DEFAULT 0,
    UNIQUE(pinyin, text)
);

CREATE INDEX IF NOT EXISTS idx_dict_user_pinyin ON dict_user(pinyin);

CREATE TABLE IF NOT EXISTS dict_user_literal (
    pinyin TEXT NOT NULL,
    jianpin TEXT NOT NULL,
    text TEXT NOT NULL,
    created_at INTEGER DEFAULT 0,
    PRIMARY KEY(pinyin, text)
);

CREATE INDEX IF NOT EXISTS idx_dict_user_literal_pinyin ON dict_user_literal(pinyin);
CREATE INDEX IF NOT EXISTS idx_dict_user_literal_compact_pinyin
ON dict_user_literal(REPLACE(pinyin, char(39), substr(pinyin, 1, 0)));
CREATE INDEX IF NOT EXISTS idx_dict_user_literal_jianpin ON dict_user_literal(jianpin);
CREATE INDEX IF NOT EXISTS idx_dict_user_literal_text ON dict_user_literal(text);

CREATE TABLE IF NOT EXISTS dict_user_stats (
    pinyin TEXT NOT NULL,
    text TEXT NOT NULL,
    commit_count INTEGER DEFAULT 0,
    last_used INTEGER DEFAULT 0,
    PRIMARY KEY(pinyin, text)
);

CREATE INDEX IF NOT EXISTS idx_dict_user_stats_pinyin ON dict_user_stats(pinyin);
CREATE INDEX IF NOT EXISTS idx_dict_user_stats_text ON dict_user_stats(text);

CREATE TABLE IF NOT EXISTS dict_user_fuzzy_choice (
    pinyin TEXT NOT NULL,
    text TEXT NOT NULL,
    commit_count INTEGER DEFAULT 0,
    last_used INTEGER DEFAULT 0,
    PRIMARY KEY(pinyin, text)
);

CREATE INDEX IF NOT EXISTS idx_dict_user_fuzzy_choice_pinyin
ON dict_user_fuzzy_choice(pinyin);

CREATE TABLE IF NOT EXISTS dict_user_query_latest (
    query_pinyin TEXT NOT NULL PRIMARY KEY,
    text TEXT NOT NULL,
    last_used INTEGER DEFAULT 0
);

CREATE INDEX IF NOT EXISTS idx_dict_user_query_latest_text ON dict_user_query_latest(text);

CREATE TABLE IF NOT EXISTS dict_user_context_query_choice (
    context_suffix TEXT NOT NULL,
    query_pinyin TEXT NOT NULL,
    text TEXT NOT NULL,
    commit_count INTEGER DEFAULT 0,
    last_used INTEGER DEFAULT 0,
    PRIMARY KEY(context_suffix, query_pinyin, text)
);

CREATE INDEX IF NOT EXISTS idx_dict_user_context_query_choice_lookup
ON dict_user_context_query_choice(context_suffix, query_pinyin);

CREATE INDEX IF NOT EXISTS idx_dict_user_context_query_choice_last_used
ON dict_user_context_query_choice(last_used);

CREATE TABLE IF NOT EXISTS dict_user_completion_feedback (
    typed_prefix TEXT NOT NULL,
    full_pinyin TEXT NOT NULL,
    text TEXT NOT NULL,
    accept_count INTEGER DEFAULT 0,
    reject_count INTEGER DEFAULT 0,
    last_used INTEGER DEFAULT 0,
    PRIMARY KEY(typed_prefix, full_pinyin, text)
) WITHOUT ROWID;

CREATE INDEX IF NOT EXISTS idx_dict_user_completion_feedback_prefix
ON dict_user_completion_feedback(typed_prefix, accept_count DESC, last_used DESC);

CREATE TABLE IF NOT EXISTS dict_user_long_completion_feedback (
    anchor_path TEXT NOT NULL,
    suffix_text TEXT NOT NULL,
    accept_count INTEGER DEFAULT 0,
    reject_count INTEGER DEFAULT 0,
    last_used INTEGER DEFAULT 0,
    PRIMARY KEY(anchor_path, suffix_text)
) WITHOUT ROWID;

CREATE INDEX IF NOT EXISTS idx_dict_user_long_completion_feedback_anchor
ON dict_user_long_completion_feedback(
    anchor_path, accept_count DESC, last_used DESC);

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

CREATE TABLE IF NOT EXISTS dict_user_trigram (
    prev_prev_text TEXT NOT NULL,
    prev_text TEXT NOT NULL,
    text TEXT NOT NULL,
    commit_count INTEGER DEFAULT 0,
    last_used INTEGER DEFAULT 0,
    PRIMARY KEY(prev_prev_text, prev_text, text)
);

CREATE INDEX IF NOT EXISTS idx_dict_user_trigram_prev_pair ON dict_user_trigram(prev_prev_text, prev_text);

CREATE TABLE IF NOT EXISTS dict_user_query_path (
    query_pinyin TEXT NOT NULL,
    path_text TEXT NOT NULL,
    commit_count INTEGER DEFAULT 0,
    last_used INTEGER DEFAULT 0,
    PRIMARY KEY(query_pinyin, path_text)
);

CREATE INDEX IF NOT EXISTS idx_dict_user_query_path_query ON dict_user_query_path(query_pinyin);

CREATE TABLE IF NOT EXISTS dict_user_query_path_penalty (
    query_pinyin TEXT NOT NULL,
    path_text TEXT NOT NULL,
    penalty INTEGER DEFAULT 0,
    last_used INTEGER DEFAULT 0,
    PRIMARY KEY(query_pinyin, path_text)
);

CREATE INDEX IF NOT EXISTS idx_dict_user_query_path_penalty_query ON dict_user_query_path_penalty(query_pinyin);

CREATE TABLE IF NOT EXISTS dict_base_query_path (
    query_pinyin TEXT NOT NULL,
    path_text TEXT NOT NULL,
    weight INTEGER DEFAULT 0,
    PRIMARY KEY(query_pinyin, path_text)
);

CREATE INDEX IF NOT EXISTS idx_dict_base_query_path_query ON dict_base_query_path(query_pinyin);

CREATE TABLE IF NOT EXISTS dict_base_lm_transition (
    query_pinyin TEXT NOT NULL,
    path_text TEXT NOT NULL,
    weight INTEGER DEFAULT 0,
    PRIMARY KEY(query_pinyin, path_text)
);

CREATE INDEX IF NOT EXISTS idx_dict_base_lm_transition_query
    ON dict_base_lm_transition(query_pinyin);

CREATE TABLE IF NOT EXISTS dict_base_transition_completion (
    typed_prefix TEXT NOT NULL,
    full_pinyin TEXT NOT NULL,
    text TEXT NOT NULL,
    path_text TEXT NOT NULL,
    evidence INTEGER NOT NULL DEFAULT 0,
    PRIMARY KEY(typed_prefix, full_pinyin, text)
) WITHOUT ROWID;

CREATE INDEX IF NOT EXISTS idx_dict_base_transition_completion_prefix
ON dict_base_transition_completion(typed_prefix, evidence DESC);

CREATE TABLE IF NOT EXISTS dict_base_long_completion (
    anchor_path TEXT NOT NULL,
    suffix_pinyin TEXT NOT NULL,
    suffix_text TEXT NOT NULL,
    suffix_path TEXT NOT NULL,
    evidence INTEGER NOT NULL DEFAULT 0,
    source_count INTEGER NOT NULL DEFAULT 0,
    PRIMARY KEY(anchor_path, suffix_pinyin, suffix_text)
) WITHOUT ROWID;

CREATE INDEX IF NOT EXISTS idx_dict_base_long_completion_anchor
ON dict_base_long_completion(anchor_path, evidence DESC, source_count DESC);

CREATE TABLE IF NOT EXISTS dict_base_long_completion_text (
    anchor_text TEXT NOT NULL,
    anchor_path TEXT NOT NULL,
    suffix_pinyin TEXT NOT NULL,
    suffix_text TEXT NOT NULL,
    suffix_path TEXT NOT NULL,
    evidence INTEGER NOT NULL DEFAULT 0,
    source_count INTEGER NOT NULL DEFAULT 0,
    PRIMARY KEY(anchor_text, anchor_path, suffix_pinyin, suffix_text)
) WITHOUT ROWID;

CREATE INDEX IF NOT EXISTS idx_dict_base_long_completion_text_anchor
ON dict_base_long_completion_text(anchor_text, evidence DESC, source_count DESC);

CREATE TABLE IF NOT EXISTS dict_base_char_lm (
    ngram TEXT NOT NULL PRIMARY KEY,
    score INTEGER NOT NULL DEFAULT 0,
    backoff INTEGER NOT NULL DEFAULT 0
) WITHOUT ROWID;

CREATE TABLE IF NOT EXISTS dict_base_char_reverse_lm (
    ngram TEXT NOT NULL PRIMARY KEY,
    score INTEGER NOT NULL DEFAULT 0,
    backoff INTEGER NOT NULL DEFAULT 0
) WITHOUT ROWID;
