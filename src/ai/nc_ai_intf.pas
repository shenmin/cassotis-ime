unit nc_ai_intf;

interface

uses
    nc_types;

type
    TncAiContext = record
        composition_text: string;
        left_context: string;
    end;

    TncAiRequest = record
        context: TncAiContext;
        max_suggestions: Integer;
        timeout_ms: Integer;
    end;

    TncAiResponse = record
        candidates: TncCandidateList;
        success: Boolean;
    end;

    TncAiProvider = class
    public
        function request_suggestions(const request: TncAiRequest; out response: TncAiResponse): Boolean; virtual; abstract;
    end;

implementation

end.
