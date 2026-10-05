unit nc_one_key_completion_difference_model;

{ Categories of a one-key completion pair (incumbent, challenger), shared by
  the ncgpt trees and the sparse audit. The linear difference ranker this unit
  once held was retired in model consolidation step 7. }

interface

uses
    nc_types;

type
    TncOneKeyCompletionDifferenceCategory = (
        okdc_base_to_transition, okdc_transition_to_base,
        okdc_hot_exact, okdc_warm_exact,
        okdc_cold_vertical_exact, okdc_generic
    );

function one_key_completion_difference_category(
    const incumbent, challenger: TncOneKeyCompletion):
    TncOneKeyCompletionDifferenceCategory;

implementation

function one_key_completion_difference_category(
    const incumbent, challenger: TncOneKeyCompletion):
    TncOneKeyCompletionDifferenceCategory;
begin
    if (incumbent.source = okcs_base_exact) and
        (challenger.source = okcs_transition) then
        Exit(okdc_base_to_transition);
    if (incumbent.source = okcs_transition) and
        (challenger.source = okcs_base_exact) then
        Exit(okdc_transition_to_base);
    if incumbent.source = okcs_base_exact then
    begin
        if (incumbent.popularity_prior >= 700) and
            (incumbent.source_count >= 2) then Exit(okdc_hot_exact);
        if incumbent.popularity_prior >= 480 then Exit(okdc_warm_exact);
        if (incumbent.vertical_layer_kind > 0) and
            (incumbent.popularity_prior >= 0) and
            (incumbent.popularity_prior < 300) then
            Exit(okdc_cold_vertical_exact);
    end;
    Result := okdc_generic;
end;

end.
