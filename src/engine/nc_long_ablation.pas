unit nc_long_ablation;

{ Development-only switches that remove one long-sentence or short-word
  ranking stage for an ablation run: CASSOTIS_LONG_ABLATE=name[,name...]. With the variable unset
  every stage runs as before. Read once at startup, so hot search loops only
  index an array. }

interface

type
    TncLongAblation = (
        la_pool_ranker, la_pool_final_pairwise, la_second_slot_bidirectional,
        la_second_slot_recovery, la_second_slot_selector, la_settled_top2,
        la_unified_top2, la_second_stage, la_exact_edge_lattice,
        la_local_pairwise_pool, la_local_residual, la_exact_anchor_pairwise,
        la_short_nocontext, la_short_reranker, la_short_residual,
        la_short_difference);

function nc_long_ablated(const stage: TncLongAblation): Boolean;

implementation

uses
    System.SysUtils;

const
    c_names: array[TncLongAblation] of string = (
        'pool_ranker', 'pool_final_pairwise', 'second_slot_bidirectional',
        'second_slot_recovery', 'second_slot_selector', 'settled_top2',
        'unified_top2', 'second_stage', 'exact_edge_lattice',
        'local_pairwise_pool', 'local_residual', 'exact_anchor_pairwise',
        'short_nocontext', 'short_reranker', 'short_residual',
        'short_difference');

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
