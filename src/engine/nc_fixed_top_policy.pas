unit nc_fixed_top_policy;

interface

uses nc_types;

// Whole-query preferences only, never weights for sentence/lattice edges.
function nc_fixed_top_text(const normalized_query: string;
    const syllable_count: Integer; const variant: TncDictionaryVariant): string;

implementation

type
    TFixedTopEntry = record
        pinyin, simplified, traditional: string;
    end;

const
    c_fixed_top: array[0..34] of TFixedTopEntry = (
        (pinyin:'en'; simplified:#$55EF; traditional:#$55EF),
        (pinyin:'ba'; simplified:#$5427; traditional:#$5427),
        (pinyin:'e'; simplified:#$5443; traditional:#$5443),
        (pinyin:'o'; simplified:#$54E6; traditional:#$54E6),
        (pinyin:'ai'; simplified:#$5509; traditional:#$5509),
        (pinyin:'ha'; simplified:#$54C8; traditional:#$54C8),
        (pinyin:'xi'; simplified:#$563B; traditional:#$563B),
        (pinyin:'bang'; simplified:#$68D2; traditional:#$68D2),
        (pinyin:'ya'; simplified:#$5440; traditional:#$5440),
        (pinyin:'qie'; simplified:#$5207; traditional:#$5207),
        (pinyin:'ca'; simplified:#$64E6; traditional:#$64E6),
        (pinyin:'gun'; simplified:#$6EDA; traditional:#$6EFE),
        (pinyin:'hei'; simplified:#$563F; traditional:#$563F),
        (pinyin:'pi'; simplified:#$5C41; traditional:#$5C41),
        (pinyin:'de'; simplified:#$7684; traditional:#$7684),
        (pinyin:'zhe'; simplified:#$8FD9; traditional:#$9019),
        (pinyin:'er'; simplified:#$800C; traditional:#$800C),
        (pinyin:'he'; simplified:#$548C; traditional:#$548C),
        (pinyin:'shi'; simplified:#$662F; traditional:#$662F),
        (pinyin:'qing'; simplified:#$8BF7; traditional:#$8ACB),
        (pinyin:'you'; simplified:#$6709; traditional:#$6709),
        (pinyin:'zheshi'; simplified:#$8FD9#$662F; traditional:#$9019#$662F),
        (pinyin:'zai'; simplified:#$5728; traditional:#$5728),
        (pinyin:'wo'; simplified:#$6211; traditional:#$6211),
        (pinyin:'ni'; simplified:#$4F60; traditional:#$4F60),
        (pinyin:'ta'; simplified:#$4ED6; traditional:#$4ED6),
        (pinyin:'qu'; simplified:#$53BB; traditional:#$53BB),
        (pinyin:'ye'; simplified:#$4E5F; traditional:#$4E5F),
        (pinyin:'yu'; simplified:#$4E0E; traditional:#$8207),
        (pinyin:'hui'; simplified:#$4F1A; traditional:#$6703),
        (pinyin:'hao'; simplified:#$597D; traditional:#$597D),
        (pinyin:'xing'; simplified:#$884C; traditional:#$884C),
        (pinyin:'ying'; simplified:#$5E94; traditional:#$61C9),
        (pinyin:'jiu'; simplified:#$5C31; traditional:#$5C31),
        (pinyin:'bu'; simplified:#$4E0D; traditional:#$4E0D));

function nc_fixed_top_text(const normalized_query: string;
    const syllable_count: Integer; const variant: TncDictionaryVariant): string;
var idx: Integer;
begin
    Result := '';
    if (syllable_count < 1) or (syllable_count > 2) or
        (Length(normalized_query) > 6) then Exit;
    for idx := Low(c_fixed_top) to High(c_fixed_top) do
        if (normalized_query = c_fixed_top[idx].pinyin) and
            (syllable_count = Length(c_fixed_top[idx].simplified)) then
        begin
            if variant = dv_traditional then
                Result := c_fixed_top[idx].traditional
            else
                Result := c_fixed_top[idx].simplified;
            Exit;
        end;
end;

end.
