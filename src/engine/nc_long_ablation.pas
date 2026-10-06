unit nc_long_ablation;

{ Development-only switches that remove one long-sentence or short-word
  ranking stage for an ablation run: CASSOTIS_LONG_ABLATE=name[,name...]. With the variable unset
  every stage runs as before. Read once at startup, so hot search loops only
  index an array. }

interface

type
    TncLongAblation = (
        la_pool_ranker, la_second_slot_recovery, la_second_slot_selector,
        la_second_stage, la_exact_edge_lattice,
        la_local_pairwise_pool, la_local_residual, la_exact_anchor_pairwise,
        la_short_nocontext,
        // Not a ranking stage: a key that completes a long input's pinyin is
        // decoded as a whole input. Ablated, it extends what earlier keys left.
        la_keystroke_whole_decode);

function nc_long_ablated(const stage: TncLongAblation): Boolean;

implementation

uses
    System.SysUtils;

const
    c_names: array[TncLongAblation] of string = (
        'pool_ranker', 'second_slot_recovery', 'second_slot_selector',
        'second_stage', 'exact_edge_lattice',
        'local_pairwise_pool', 'local_residual', 'exact_anchor_pairwise',
        'short_nocontext', 'keystroke_whole_decode');

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
