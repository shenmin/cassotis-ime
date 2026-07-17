unit nc_dpi_scale;

interface

const
    c_nc_base_dpi = 96;
    c_nc_points_per_inch = 72;

function nc_normalize_dpi(const dpi: Integer): Integer;
function nc_scale_for_dpi(const logical_value: Integer; const dpi: Integer): Integer;
function nc_font_height_for_dpi(const point_size: Integer; const dpi: Integer): Integer;

implementation

uses
    Winapi.Windows;

function nc_normalize_dpi(const dpi: Integer): Integer;
begin
    Result := dpi;
    if Result <= 0 then
    begin
        Result := c_nc_base_dpi;
    end;
end;

function nc_scale_for_dpi(const logical_value: Integer; const dpi: Integer): Integer;
begin
    Result := MulDiv(logical_value, nc_normalize_dpi(dpi), c_nc_base_dpi);
end;

function nc_font_height_for_dpi(const point_size: Integer; const dpi: Integer): Integer;
var
    pixel_height: Integer;
begin
    pixel_height := MulDiv(point_size, nc_normalize_dpi(dpi), c_nc_points_per_inch);
    if pixel_height < 1 then
    begin
        pixel_height := 1;
    end;
    Result := -pixel_height;
end;

end.
