unit nc_ai_null;

interface

uses
    nc_ai_intf;

type
    TncAiNullProvider = class(TncAiProvider)
    public
        function request_suggestions(const request: TncAiRequest; out response: TncAiResponse): Boolean; override;
    end;

implementation

function TncAiNullProvider.request_suggestions(const request: TncAiRequest; out response: TncAiResponse): Boolean;
begin
    response.success := False;
    SetLength(response.candidates, 0);
    Result := False;
end;

end.
