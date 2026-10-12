unit nc_long_ablation;

{ Development-only switches that remove one long-sentence or short-word
  ranking stage for an ablation run: CASSOTIS_LONG_ABLATE=name[,name...]. With the variable unset
  every stage runs as before. Read once at startup, so hot search loops only
  index an array. }

interface

type
    TncLongAblation = (
        la_pool_ranker, la_exact_edge_lattice,
        la_short_nocontext,
        // The short-word LM choice also runs without left context. Ablated,
        // it leaves such input to the dictionary order.
        la_short_empty_context,
        // Not a ranking stage: a key that completes a long input's pinyin is
        // decoded as a whole input. Ablated, it extends what earlier keys left.
        la_keystroke_whole_decode,
        // Not a ranking stage either: the long choice's runner-up, and the
        // choice a repair replaces, take the second complete slot. Ablated,
        // the second slot is what the final ranking left there.
        la_second_slot_choice,
        // The stage that writes a phrase of three to five syllables which is
        // no dictionary entry (the shared LM picks a draft, the
        // pinyin-conditioned model corrects it). Ablated, the page is what
        // the dictionary paths left; short_phrase_draft alone takes the first
        // draft without asking the shared LM.
        la_short_phrase, la_short_phrase_draft);

function nc_long_ablated(const stage: TncLongAblation): Boolean;

implementation

uses
    System.SysUtils;

const
    c_names: array[TncLongAblation] of string = (
        'pool_ranker', 'exact_edge_lattice',
        'short_nocontext', 'short_empty_context',
        'keystroke_whole_decode', 'second_slot_choice',
        'short_phrase', 'short_phrase_draft');

var
    g_ablated: array[TncLongAblation] of Boolean;

function nc_long_ablated(const stage: TncLongAblation): Boolean;
begin
    Result := g_ablated[stage];
end;

procedure load_ablations;
var
    name: string;
    stage: TncLongAblation;
begin
    for name in GetEnvironmentVariable('CASSOTIS_LONG_ABLATE').Split([',', ';', ' ']) do
        for stage := Low(TncLongAblation) to High(TncLongAblation) do
            if SameText(Trim(name), c_names[stage]) then
                g_ablated[stage] := True;
end;

initialization
    load_ablations;

end.
