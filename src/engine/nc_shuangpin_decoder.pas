unit nc_shuangpin_decoder;

interface

uses
    nc_types;

type
    TncShuangpinDecodedUnit = record
        pinyin: string;
        raw_text: string;
        raw_start: Integer;
        raw_length: Integer;
        complete: Boolean;
        force_boundary_before: Boolean;
    end;

    TncShuangpinDecodeResult = record
        raw_text: string;
        canonical_text: string;
        compact_pinyin: string;
        units: TArray<TncShuangpinDecodedUnit>;
        valid: Boolean;
        has_pending_key: Boolean;
    end;

function nc_is_shuangpin_scheme(const scheme: TncPinyinInputScheme): Boolean;
function nc_decode_shuangpin(const scheme: TncPinyinInputScheme;
    const raw_text: string): TncShuangpinDecodeResult;
function nc_get_shuangpin_codes(const scheme: TncPinyinInputScheme;
    const syllable: string): TArray<string>;
function nc_get_shuangpin_syllables: TArray<string>;
function nc_shuangpin_raw_prefix_for_units(const decoded: TncShuangpinDecodeResult;
    const unit_count: Integer): string;
function nc_shuangpin_raw_suffix_after_units(const decoded: TncShuangpinDecodeResult;
    const unit_count: Integer): string;
function nc_shuangpin_accepts_semicolon(const scheme: TncPinyinInputScheme;
    const raw_text: string): Boolean;

implementation

uses
    System.SysUtils,
    System.Classes,
    System.Generics.Collections,
    nc_pinyin_parser;

const
    // This is the stable, scheme-independent Mandarin syllable inventory used
    // by Cassotis dictionaries. It also keeps established marginal readings
    // such as hm/ng/lo instead of deriving an over-permissive Cartesian product.
    c_pinyin_syllables =
        'a ai an ang ao ba bai ban bang bao bei ben beng bi bian biao bie bin bing bo bu ' +
        'ca cai can cang cao ce cen ceng cha chai chan chang chao che chen cheng chi chong chou ' +
        'chu chua chuai chuan chuang chui chun chuo ci cong cou cu cuan cui cun cuo ' +
        'da dai dan dang dao de dei den deng di dia dian diao die ding diu dong dou du duan dui dun duo ' +
        'e ei en eng er fa fan fang fei fen feng fiao fo fou fu ' +
        'ga gai gan gang gao ge gei gen geng gong gou gu gua guai guan guang gui gun guo ' +
        'ha hai han hang hao he hei hen heng hm hong hou hu hua huai huan huang hui hun huo ' +
        'ji jia jian jiang jiao jie jin jing jiong jiu ju juan jue jun ' +
        'ka kai kan kang kao ke ken keng kong kou ku kua kuai kuan kuang kui kun kuo ' +
        'la lai lan lang lao le lei leng li lia lian liang liao lie lin ling liu lo long lou lu luan lun luo lv lve ' +
        'm ma mai man mang mao me mei men meng mi mian miao mie min ming miu mo mou mu ' +
        'n na nai nan nang nao ne nei nen neng ng ni nian niang niao nie nin ning niu nong nou nu nuan nun nuo nv nve ' +
        'o ou pa pai pan pang pao pei pen peng pi pian piao pie pin ping po pou pu ' +
        'qi qia qian qiang qiao qie qin qing qiong qiu qu quan que qun ' +
        'r ran rang rao re ren reng ri rong rou ru rua ruan rui run ruo ' +
        'sa sai san sang sao se sen seng sha shai shan shang shao she shei shen sheng shi shou ' +
        'shu shua shuai shuan shuang shui shun shuo si song sou su suan sui sun suo ' +
        'ta tai tan tang tao te teng ti tian tiao tie ting tong tou tu tuan tui tun tuo ' +
        'wa wai wan wang wei wen weng wo wu ' +
        'xi xia xian xiang xiao xie xin xing xiong xiu xu xuan xue xun ' +
        'ya yan yang yao ye yi yin ying yo yong you yu yuan yue yun ' +
        'za zai zan zang zao ze zei zen zeng zha zhai zhan zhang zhao zhe zhen zheng zhi ' +
        'zhong zhou zhu zhua zhuai zhuan zhuang zhui zhun zhuo zi zong zou zu zuan zui zun zuo';

var
    g_syllables: TArray<string>;
    g_microsoft_codes: TDictionary<string, string>;
    g_xiaohe_codes: TDictionary<string, string>;
    g_ziranma_codes: TDictionary<string, string>;
    g_sogou_codes: TDictionary<string, string>;
    g_ziguang_codes: TDictionary<string, string>;
    g_pinyinjiajia_codes: TDictionary<string, string>;
    g_zhinengabc_codes: TDictionary<string, string>;

function nc_is_shuangpin_scheme(const scheme: TncPinyinInputScheme): Boolean;
begin
    Result := scheme in [pis_microsoft_shuangpin, pis_xiaohe_shuangpin,
        pis_ziranma_shuangpin, pis_sogou_shuangpin,
        pis_ziguang_shuangpin, pis_pinyinjiajia_shuangpin,
        pis_zhinengabc_shuangpin];
end;

function ends_with(const value: string; const suffix: string): Boolean;
begin
    Result := (Length(value) >= Length(suffix)) and
        (Copy(value, Length(value) - Length(suffix) + 1,
        Length(suffix)) = suffix);
end;

function replace_suffix(const value: string; const suffix: string;
    const replacement: string): string;
begin
    Result := Copy(value, 1, Length(value) - Length(suffix)) + replacement;
end;

function transform_retroflex_initial(const value: string): string;
begin
    Result := value;
    if Copy(Result, 1, 2) = 'sh' then
    begin
        Result := 'U' + Copy(Result, 3, MaxInt);
    end
    else if Copy(Result, 1, 2) = 'ch' then
    begin
        Result := 'I' + Copy(Result, 3, MaxInt);
    end
    else if Copy(Result, 1, 2) = 'zh' then
    begin
        Result := 'V' + Copy(Result, 3, MaxInt);
    end;
end;

function transform_microsoft_code(const source: string): string;
var
    value: string;
begin
    value := LowerCase(source);
    if (value <> '') and CharInSet(value[1], ['a', 'e']) then
    begin
        value := value[1] + value;
    end;

    if ends_with(value, 'iu') then
        value := replace_suffix(value, 'iu', 'q')
    else if ends_with(value, 'ia') then
        value := replace_suffix(value, 'ia', 'w')
    else if ends_with(value, 'ua') then
        value := replace_suffix(value, 'ua', 'w')
    else if ends_with(value, 'er') then
        value := replace_suffix(value, 'er', 'r')
    else if ends_with(value, 'uan') then
        value := replace_suffix(value, 'uan', 'r')
    else if ends_with(value, 'van') then
        value := replace_suffix(value, 'van', 'r')
    else if ends_with(value, 'ue') then
        value := replace_suffix(value, 'ue', 't')
    else if ends_with(value, 've') then
        value := replace_suffix(value, 've', 't')
    else if ends_with(value, 'uai') then
        value := replace_suffix(value, 'uai', 'y')
    else if ends_with(value, 'v') then
        value := replace_suffix(value, 'v', 'y');

    value := transform_retroflex_initial(value);

    if ends_with(value, 'uo') then
        value := replace_suffix(value, 'uo', 'o')
    else if ends_with(value, 'un') then
        value := replace_suffix(value, 'un', 'p')
    else if ends_with(value, 'vn') then
        value := replace_suffix(value, 'vn', 'p')
    else if ends_with(value, 'iong') then
        value := replace_suffix(value, 'iong', 's')
    else if ends_with(value, 'ong') then
        value := replace_suffix(value, 'ong', 's')
    else if ends_with(value, 'iang') then
        value := replace_suffix(value, 'iang', 'd')
    else if ends_with(value, 'uang') then
        value := replace_suffix(value, 'uang', 'd')
    else if (Length(value) > 3) and ends_with(value, 'eng') then
        value := replace_suffix(value, 'eng', 'g')
    else if (Length(value) > 2) and ends_with(value, 'en') then
        value := replace_suffix(value, 'en', 'f')
    else if (Length(value) > 3) and ends_with(value, 'ang') then
        value := replace_suffix(value, 'ang', 'h')
    else if ends_with(value, 'ian') then
        value := replace_suffix(value, 'ian', 'm')
    else if (Length(value) > 2) and ends_with(value, 'an') then
        value := replace_suffix(value, 'an', 'j')
    else if ends_with(value, 'iao') then
        value := replace_suffix(value, 'iao', 'c')
    else if (Length(value) > 2) and ends_with(value, 'ao') then
        value := replace_suffix(value, 'ao', 'k')
    else if (Length(value) > 2) and ends_with(value, 'ai') then
        value := replace_suffix(value, 'ai', 'l')
    else if (Length(value) > 2) and ends_with(value, 'ei') then
        value := replace_suffix(value, 'ei', 'z')
    else if ends_with(value, 'ie') then
        value := replace_suffix(value, 'ie', 'x')
    else if ends_with(value, 'ui') then
        value := replace_suffix(value, 'ui', 'v')
    else if (Length(value) > 2) and ends_with(value, 'ou') then
        value := replace_suffix(value, 'ou', 'b')
    else if ends_with(value, 'ing') then
        value := replace_suffix(value, 'ing', ';')
    else if ends_with(value, 'in') then
        value := replace_suffix(value, 'in', 'n');

    Result := LowerCase(value);
end;

function transform_xiaohe_code(const source: string): string;
var
    value: string;
begin
    value := LowerCase(source);
    if ((Length(value) = 1) and CharInSet(value[1], ['a', 'e', 'o'])) or
        ((Length(value) = 3) and CharInSet(value[1], ['a', 'e', 'o']) and
        (Copy(value, 2, 2) = 'ng')) then
    begin
        value := value[1] + value;
    end;

    if ends_with(value, 'iu') then
        value := replace_suffix(value, 'iu', 'q')
    else if (Length(value) > 2) and ends_with(value, 'ei') then
        value := replace_suffix(value, 'ei', 'w')
    else if ends_with(value, 'uan') then
        value := replace_suffix(value, 'uan', 'r')
    else if ends_with(value, 'ue') then
        value := replace_suffix(value, 'ue', 't')
    else if ends_with(value, 've') then
        value := replace_suffix(value, 've', 't')
    else if ends_with(value, 'un') then
        value := replace_suffix(value, 'un', 'y');

    value := transform_retroflex_initial(value);

    if ends_with(value, 'uo') then
        value := replace_suffix(value, 'uo', 'o')
    else if ends_with(value, 'ie') then
        value := replace_suffix(value, 'ie', 'p')
    else if ends_with(value, 'iong') then
        value := replace_suffix(value, 'iong', 's')
    else if ends_with(value, 'ong') then
        value := replace_suffix(value, 'ong', 's')
    else if ends_with(value, 'uai') then
        value := replace_suffix(value, 'uai', 'k')
    else if ends_with(value, 'ing') then
        value := replace_suffix(value, 'ing', 'k')
    else if (Length(value) > 2) and ends_with(value, 'ai') then
        value := replace_suffix(value, 'ai', 'd')
    else if (Length(value) > 3) and ends_with(value, 'eng') then
        value := replace_suffix(value, 'eng', 'g')
    else if (Length(value) > 2) and ends_with(value, 'en') then
        value := replace_suffix(value, 'en', 'f')
    else if ends_with(value, 'iang') then
        value := replace_suffix(value, 'iang', 'l')
    else if ends_with(value, 'uang') then
        value := replace_suffix(value, 'uang', 'l')
    else if (Length(value) > 3) and ends_with(value, 'ang') then
        value := replace_suffix(value, 'ang', 'h')
    else if ends_with(value, 'ian') then
        value := replace_suffix(value, 'ian', 'm')
    else if (Length(value) > 2) and ends_with(value, 'an') then
        value := replace_suffix(value, 'an', 'j')
    else if (Length(value) > 2) and ends_with(value, 'ou') then
        value := replace_suffix(value, 'ou', 'z')
    else if ends_with(value, 'ia') then
        value := replace_suffix(value, 'ia', 'x')
    else if ends_with(value, 'ua') then
        value := replace_suffix(value, 'ua', 'x')
    else if ends_with(value, 'iao') then
        value := replace_suffix(value, 'iao', 'n')
    else if (Length(value) > 2) and ends_with(value, 'ao') then
        value := replace_suffix(value, 'ao', 'c')
    else if ends_with(value, 'ui') then
        value := replace_suffix(value, 'ui', 'v')
    else if ends_with(value, 'in') then
        value := replace_suffix(value, 'in', 'b');

    Result := LowerCase(value);
end;

function transform_ziranma_code(const source: string): string;
var
    value: string;
begin
    value := LowerCase(source);
    if ((Length(value) = 1) and CharInSet(value[1], ['a', 'e', 'o'])) or
        ((Length(value) = 3) and CharInSet(value[1], ['a', 'e', 'o']) and
        (Copy(value, 2, 2) = 'ng')) then
    begin
        value := value[1] + value;
    end;

    if ends_with(value, 'iu') then
        value := replace_suffix(value, 'iu', 'q')
    else if ends_with(value, 'ia') then
        value := replace_suffix(value, 'ia', 'w')
    else if ends_with(value, 'ua') then
        value := replace_suffix(value, 'ua', 'w')
    else if ends_with(value, 'uan') then
        value := replace_suffix(value, 'uan', 'r')
    else if ends_with(value, 'van') then
        value := replace_suffix(value, 'van', 'r')
    else if ends_with(value, 'ue') then
        value := replace_suffix(value, 'ue', 't')
    else if ends_with(value, 've') then
        value := replace_suffix(value, 've', 't')
    else if ends_with(value, 'ing') then
        value := replace_suffix(value, 'ing', 'y')
    else if ends_with(value, 'uai') then
        value := replace_suffix(value, 'uai', 'y');

    value := transform_retroflex_initial(value);

    if ends_with(value, 'uo') then
        value := replace_suffix(value, 'uo', 'o')
    else if ends_with(value, 'un') then
        value := replace_suffix(value, 'un', 'p')
    else if ends_with(value, 'vn') then
        value := replace_suffix(value, 'vn', 'p')
    else if ends_with(value, 'iong') then
        value := replace_suffix(value, 'iong', 's')
    else if ends_with(value, 'ong') then
        value := replace_suffix(value, 'ong', 's')
    else if ends_with(value, 'iang') then
        value := replace_suffix(value, 'iang', 'd')
    else if ends_with(value, 'uang') then
        value := replace_suffix(value, 'uang', 'd')
    else if (Length(value) > 2) and ends_with(value, 'en') then
        value := replace_suffix(value, 'en', 'f')
    else if (Length(value) > 3) and ends_with(value, 'eng') then
        value := replace_suffix(value, 'eng', 'g')
    else if (Length(value) > 3) and ends_with(value, 'ang') then
        value := replace_suffix(value, 'ang', 'h')
    else if ends_with(value, 'ian') then
        value := replace_suffix(value, 'ian', 'm')
    else if (Length(value) > 2) and ends_with(value, 'an') then
        value := replace_suffix(value, 'an', 'j')
    else if ends_with(value, 'iao') then
        value := replace_suffix(value, 'iao', 'c')
    else if (Length(value) > 2) and ends_with(value, 'ao') then
        value := replace_suffix(value, 'ao', 'k')
    else if (Length(value) > 2) and ends_with(value, 'ai') then
        value := replace_suffix(value, 'ai', 'l')
    else if (Length(value) > 2) and ends_with(value, 'ei') then
        value := replace_suffix(value, 'ei', 'z')
    else if ends_with(value, 'ie') then
        value := replace_suffix(value, 'ie', 'x')
    else if ends_with(value, 'ui') then
        value := replace_suffix(value, 'ui', 'v')
    else if (Length(value) > 2) and ends_with(value, 'ou') then
        value := replace_suffix(value, 'ou', 'b')
    else if ends_with(value, 'in') then
        value := replace_suffix(value, 'in', 'n');

    Result := LowerCase(value);
end;

function transform_sogou_code(const source: string): string;
var
    value: string;
begin
    value := LowerCase(source);
    if (value <> '') and CharInSet(value[1], ['a', 'e']) then
    begin
        value := value[1] + value;
    end;

    if ends_with(value, 'iu') then
        value := replace_suffix(value, 'iu', 'q')
    else if ends_with(value, 'ia') then
        value := replace_suffix(value, 'ia', 'w')
    else if ends_with(value, 'ua') then
        value := replace_suffix(value, 'ua', 'w')
    else if ends_with(value, 'er') then
        value := replace_suffix(value, 'er', 'r')
    else if ends_with(value, 'uan') then
        value := replace_suffix(value, 'uan', 'r')
    else if ends_with(value, 'van') then
        value := replace_suffix(value, 'van', 'r')
    else if ends_with(value, 'ue') then
        value := replace_suffix(value, 'ue', 't')
    else if ends_with(value, 've') then
        value := replace_suffix(value, 've', 't')
    else if ends_with(value, 'uai') then
        value := replace_suffix(value, 'uai', 'y')
    else if ends_with(value, 'v') then
        value := replace_suffix(value, 'v', 'y');

    value := transform_retroflex_initial(value);

    if ends_with(value, 'uo') then
        value := replace_suffix(value, 'uo', 'o')
    else if ends_with(value, 'un') then
        value := replace_suffix(value, 'un', 'p')
    else if ends_with(value, 'vn') then
        value := replace_suffix(value, 'vn', 'p')
    else if ends_with(value, 'iong') then
        value := replace_suffix(value, 'iong', 's')
    else if ends_with(value, 'ong') then
        value := replace_suffix(value, 'ong', 's')
    else if ends_with(value, 'iang') then
        value := replace_suffix(value, 'iang', 'd')
    else if ends_with(value, 'uang') then
        value := replace_suffix(value, 'uang', 'd')
    else if (Length(value) > 3) and ends_with(value, 'eng') then
        value := replace_suffix(value, 'eng', 'g')
    else if (Length(value) > 2) and ends_with(value, 'en') then
        value := replace_suffix(value, 'en', 'f')
    else if (Length(value) > 3) and ends_with(value, 'ang') then
        value := replace_suffix(value, 'ang', 'h')
    else if ends_with(value, 'ian') then
        value := replace_suffix(value, 'ian', 'm')
    else if (Length(value) > 2) and ends_with(value, 'an') then
        value := replace_suffix(value, 'an', 'j')
    else if ends_with(value, 'iao') then
        value := replace_suffix(value, 'iao', 'c')
    else if (Length(value) > 2) and ends_with(value, 'ao') then
        value := replace_suffix(value, 'ao', 'k')
    else if (Length(value) > 2) and ends_with(value, 'ai') then
        value := replace_suffix(value, 'ai', 'l')
    else if (Length(value) > 2) and ends_with(value, 'ei') then
        value := replace_suffix(value, 'ei', 'z')
    else if ends_with(value, 'ie') then
        value := replace_suffix(value, 'ie', 'x')
    else if ends_with(value, 'ui') then
        value := replace_suffix(value, 'ui', 'v')
    else if (Length(value) > 2) and ends_with(value, 'ou') then
        value := replace_suffix(value, 'ou', 'b')
    else if ends_with(value, 'ing') then
        value := replace_suffix(value, 'ing', ';')
    else if ends_with(value, 'in') then
        value := replace_suffix(value, 'in', 'n');

    Result := LowerCase(value);
end;

function transform_ziguang_initial(const value: string): string;
begin
    Result := value;
    if Copy(Result, 1, 2) = 'sh' then
    begin
        Result := 'i' + Copy(Result, 3, MaxInt);
    end
    else if Copy(Result, 1, 2) = 'ch' then
    begin
        Result := 'a' + Copy(Result, 3, MaxInt);
    end
    else if Copy(Result, 1, 2) = 'zh' then
    begin
        Result := 'u' + Copy(Result, 3, MaxInt);
    end;
end;

function transform_ziguang_code(const source: string): string;
var
    value: string;
    initial_code: string;
    initial_length: Integer;
begin
    value := LowerCase(source);
    // Preserve the original initial (including the zero-initial o prefix).
    // A generated final key must never be reinterpreted as part of sh/ch/zh.
    initial_length := 1;
    if (Copy(value, 1, 2) = 'sh') or (Copy(value, 1, 2) = 'ch') or
        (Copy(value, 1, 2) = 'zh') then
    begin
        initial_length := 2;
    end;
    initial_code := transform_ziguang_initial(Copy(value, 1, initial_length));
    value := Copy(value, initial_length + 1, MaxInt);
    if ends_with(value, 'uai') then
        value := replace_suffix(value, 'uai', 'y')
    else if ends_with(value, 'iang') then
        value := replace_suffix(value, 'iang', 'g')
    else if ends_with(value, 'uang') then
        value := replace_suffix(value, 'uang', 'g')
    else if ends_with(value, 'iong') then
        value := replace_suffix(value, 'iong', 'h')
    else if ends_with(value, 'eng') then
        value := replace_suffix(value, 'eng', 't')
    else if ends_with(value, 'ang') then
        value := replace_suffix(value, 'ang', 's')
    else if ends_with(value, 'ian') then
        value := replace_suffix(value, 'ian', 'f')
    else if ends_with(value, 'uan') then
        value := replace_suffix(value, 'uan', 'l')
    else if ends_with(value, 'ing') then
        value := replace_suffix(value, 'ing', ';')
    else if ends_with(value, 'iao') then
        value := replace_suffix(value, 'iao', 'b')
    else if ends_with(value, 'ong') then
        value := replace_suffix(value, 'ong', 'h')
    else if ends_with(value, 'uo') then
        value := replace_suffix(value, 'uo', 'o')
    else if ends_with(value, 'ai') then
        value := replace_suffix(value, 'ai', 'p')
    else if ends_with(value, 'ie') then
        value := replace_suffix(value, 'ie', 'd')
    else if ends_with(value, 'er') then
        value := replace_suffix(value, 'er', 'j')
    else if ends_with(value, 'iu') then
        value := replace_suffix(value, 'iu', 'j')
    else if ends_with(value, 'ei') then
        value := replace_suffix(value, 'ei', 'k')
    else if ends_with(value, 'ou') then
        value := replace_suffix(value, 'ou', 'z')
    else if ends_with(value, 'ia') then
        value := replace_suffix(value, 'ia', 'x')
    else if ends_with(value, 'ua') then
        value := replace_suffix(value, 'ua', 'x')
    else if ends_with(value, 'ue') then
        value := replace_suffix(value, 'ue', 'n')
    else if ends_with(value, 've') then
        value := replace_suffix(value, 've', 'n')
    else if ends_with(value, 'ui') then
        value := replace_suffix(value, 'ui', 'n')
    else if ends_with(value, 'un') then
        value := replace_suffix(value, 'un', 'm')
    else if ends_with(value, 'en') then
        value := replace_suffix(value, 'en', 'w')
    else if ends_with(value, 'ao') then
        value := replace_suffix(value, 'ao', 'q')
    else if ends_with(value, 'an') then
        value := replace_suffix(value, 'an', 'r')
    else if ends_with(value, 'in') then
        value := replace_suffix(value, 'in', 'y');

    Result := initial_code + value;
end;

function transform_pinyinjiajia_initial(const value: string): string;
begin
    Result := value;
    if Copy(Result, 1, 2) = 'sh' then
    begin
        Result := 'i' + Copy(Result, 3, MaxInt);
    end
    else if Copy(Result, 1, 2) = 'ch' then
    begin
        Result := 'u' + Copy(Result, 3, MaxInt);
    end
    else if Copy(Result, 1, 2) = 'zh' then
    begin
        Result := 'v' + Copy(Result, 3, MaxInt);
    end;
end;

function transform_pinyinjiajia_code(const source: string): string;
var
    value: string;
begin
    value := LowerCase(source);
    if ends_with(value, 'uai') then
        value := replace_suffix(value, 'uai', 'x')
    else if ends_with(value, 'iang') then
        value := replace_suffix(value, 'iang', 'h')
    else if ends_with(value, 'uang') then
        value := replace_suffix(value, 'uang', 'h')
    else if ends_with(value, 'iong') then
        value := replace_suffix(value, 'iong', 'y')
    else if ends_with(value, 'eng') then
        value := replace_suffix(value, 'eng', 't')
    else if ends_with(value, 'ang') then
        value := replace_suffix(value, 'ang', 'g')
    else if ends_with(value, 'ian') then
        value := replace_suffix(value, 'ian', 'j')
    else if ends_with(value, 'uan') then
        value := replace_suffix(value, 'uan', 'c')
    else if ends_with(value, 'van') then
        value := replace_suffix(value, 'van', 'c')
    else if ends_with(value, 'ing') then
        value := replace_suffix(value, 'ing', 'q')
    else if ends_with(value, 'iao') then
        value := replace_suffix(value, 'iao', 'k')
    else if ends_with(value, 'ong') then
        value := replace_suffix(value, 'ong', 'y')
    else if ends_with(value, 'iu') then
        value := replace_suffix(value, 'iu', 'n')
    else if ends_with(value, 'ia') then
        value := replace_suffix(value, 'ia', 'b')
    else if ends_with(value, 'ua') then
        value := replace_suffix(value, 'ua', 'b')
    else if ends_with(value, 'er') then
        value := replace_suffix(value, 'er', 'q')
    else if ends_with(value, 'ue') then
        value := replace_suffix(value, 'ue', 'x')
    else if ends_with(value, 've') then
        value := replace_suffix(value, 've', 'x')
    else if ends_with(value, 'uo') then
        value := replace_suffix(value, 'uo', 'o')
    else if ends_with(value, 'un') then
        value := replace_suffix(value, 'un', 'z')
    else if ends_with(value, 'vn') then
        value := replace_suffix(value, 'vn', 'z')
    else if ends_with(value, 'en') then
        value := replace_suffix(value, 'en', 'r')
    else if ends_with(value, 'an') then
        value := replace_suffix(value, 'an', 'f')
    else if ends_with(value, 'ao') then
        value := replace_suffix(value, 'ao', 'd')
    else if ends_with(value, 'ai') then
        value := replace_suffix(value, 'ai', 's')
    else if ends_with(value, 'ei') then
        value := replace_suffix(value, 'ei', 'w')
    else if ends_with(value, 'ie') then
        value := replace_suffix(value, 'ie', 'm')
    else if ends_with(value, 'ui') then
        value := replace_suffix(value, 'ui', 'v')
    else if (Length(value) > 2) and ends_with(value, 'ou') then
        value := replace_suffix(value, 'ou', 'p')
    else if ends_with(value, 'in') then
        value := replace_suffix(value, 'in', 'l');

    Result := LowerCase(transform_pinyinjiajia_initial(value));
end;

// Zhineng ABC: zh, ch and sh take the keys of the finals a, e and v, and a
// syllable without an initial takes a fixed o (ai = ol, er = or), never a doubled
// vowel: aa is zha and ee is che. The initial is split off first, so that a
// final's key is never read as part of an initial (zang = zh, zhi = ai). ve shares
// the key of ue, as Rime, fcitx, Windows and macOS have it: on the v of the older
// key charts lv and lve would be one code, and a code decodes to one syllable.
function transform_zhinengabc_code(const source: string): string;
var
    value: string;
    initial_code: string;
begin
    value := LowerCase(source);
    if (value <> '') and CharInSet(value[1], ['a', 'o', 'e']) then
    begin
        initial_code := 'o';
    end
    else if Copy(value, 1, 2) = 'zh' then
    begin
        initial_code := 'a';
        Delete(value, 1, 2);
    end
    else if Copy(value, 1, 2) = 'ch' then
    begin
        initial_code := 'e';
        Delete(value, 1, 2);
    end
    else if Copy(value, 1, 2) = 'sh' then
    begin
        initial_code := 'v';
        Delete(value, 1, 2);
    end
    else
    begin
        initial_code := Copy(value, 1, 1);
        Delete(value, 1, 1);
    end;

    if ends_with(value, 'iang') then
        value := replace_suffix(value, 'iang', 't')
    else if ends_with(value, 'uang') then
        value := replace_suffix(value, 'uang', 't')
    else if ends_with(value, 'iong') then
        value := replace_suffix(value, 'iong', 's')
    else if ends_with(value, 'uai') then
        value := replace_suffix(value, 'uai', 'c')
    else if ends_with(value, 'uan') then
        value := replace_suffix(value, 'uan', 'p')
    else if ends_with(value, 'ian') then
        value := replace_suffix(value, 'ian', 'w')
    else if ends_with(value, 'iao') then
        value := replace_suffix(value, 'iao', 'z')
    else if ends_with(value, 'ing') then
        value := replace_suffix(value, 'ing', 'y')
    else if ends_with(value, 'ong') then
        value := replace_suffix(value, 'ong', 's')
    else if ends_with(value, 'eng') then
        value := replace_suffix(value, 'eng', 'g')
    else if ends_with(value, 'ang') then
        value := replace_suffix(value, 'ang', 'h')
    else if ends_with(value, 'ai') then
        value := replace_suffix(value, 'ai', 'l')
    else if ends_with(value, 'an') then
        value := replace_suffix(value, 'an', 'j')
    else if ends_with(value, 'ao') then
        value := replace_suffix(value, 'ao', 'k')
    else if ends_with(value, 'ei') then
        value := replace_suffix(value, 'ei', 'q')
    else if ends_with(value, 'en') then
        value := replace_suffix(value, 'en', 'f')
    else if ends_with(value, 'er') then
        value := replace_suffix(value, 'er', 'r')
    else if ends_with(value, 'ia') then
        value := replace_suffix(value, 'ia', 'd')
    else if ends_with(value, 'ie') then
        value := replace_suffix(value, 'ie', 'x')
    else if ends_with(value, 'in') then
        value := replace_suffix(value, 'in', 'c')
    else if ends_with(value, 'iu') then
        value := replace_suffix(value, 'iu', 'r')
    else if ends_with(value, 'ou') then
        value := replace_suffix(value, 'ou', 'b')
    else if ends_with(value, 'ua') then
        value := replace_suffix(value, 'ua', 'd')
    else if ends_with(value, 'ue') then
        value := replace_suffix(value, 'ue', 'm')
    else if ends_with(value, 've') then
        value := replace_suffix(value, 've', 'm')
    else if ends_with(value, 'ui') then
        value := replace_suffix(value, 'ui', 'm')
    else if ends_with(value, 'un') then
        value := replace_suffix(value, 'un', 'n')
    else if ends_with(value, 'uo') then
        value := replace_suffix(value, 'uo', 'o');

    Result := initial_code + value;
end;

procedure append_unique(var values: TArray<string>; const value: string);
var
    idx: Integer;
begin
    if value = '' then
    begin
        Exit;
    end;
    for idx := 0 to High(values) do
    begin
        if SameText(values[idx], value) then
        begin
            Exit;
        end;
    end;
    SetLength(values, Length(values) + 1);
    values[High(values)] := LowerCase(value);
end;

function nc_get_shuangpin_codes(const scheme: TncPinyinInputScheme;
    const syllable: string): TArray<string>;
var
    sources: TArray<string>;
    source: string;
    code: string;
    normalized: string;
begin
    SetLength(Result, 0);
    normalized := LowerCase(Trim(syllable));
    if (normalized = '') or (not nc_is_shuangpin_scheme(scheme)) then
    begin
        Exit;
    end;

    append_unique(sources, normalized);
    if (Length(normalized) = 2) and CharInSet(normalized[1], ['j', 'q', 'x', 'y']) and
        (normalized[2] = 'u') then
    begin
        append_unique(sources, normalized[1] + 'v');
    end;

    case scheme of
        pis_microsoft_shuangpin:
            begin
                if CharInSet(normalized[1], ['a', 'o', 'e']) then
                begin
                    append_unique(sources, 'o' + normalized);
                end;
                for source in sources do
                begin
                    code := transform_microsoft_code(source);
                    append_unique(Result, code);
                    if (code <> '') and (code[Length(code)] = 't') then
                    begin
                        append_unique(Result, Copy(code, 1, Length(code) - 1) + 'v');
                    end;
                end;
            end;
        pis_xiaohe_shuangpin, pis_ziranma_shuangpin:
            begin
                if (Length(normalized) = 2) and
                    CharInSet(normalized[1], ['a', 'o', 'e']) and
                    CharInSet(normalized[2], ['i', 'o', 'u', 'n']) then
                begin
                    append_unique(sources, normalized[1] + normalized);
                end;
                for source in sources do
                begin
                    if scheme = pis_xiaohe_shuangpin then
                    begin
                        append_unique(Result, transform_xiaohe_code(source));
                    end
                    else
                    begin
                        append_unique(Result, transform_ziranma_code(source));
                    end;
                end;
            end;
        pis_sogou_shuangpin:
            begin
                if CharInSet(normalized[1], ['a', 'o', 'e']) then
                begin
                    append_unique(sources, 'o' + normalized);
                end;
                for source in sources do
                begin
                    append_unique(Result, transform_sogou_code(source));
                end;
            end;
        pis_ziguang_shuangpin:
            begin
                if CharInSet(normalized[1], ['a', 'o', 'e']) then
                begin
                    append_unique(Result,
                        transform_ziguang_code('o' + normalized));
                end
                else
                begin
                    for source in sources do
                    begin
                        append_unique(Result, transform_ziguang_code(source));
                    end;
                end;
            end;
        pis_pinyinjiajia_shuangpin:
            begin
                if CharInSet(normalized[1], ['a', 'o', 'e']) then
                begin
                    if normalized[1] = 'o' then
                    begin
                        // The published algebra retains the original o-prefixed
                        // spelling (o/ou) as well as deriving oo/op aliases.
                        append_unique(Result,
                            transform_pinyinjiajia_code(normalized));
                    end;
                    append_unique(Result, transform_pinyinjiajia_code(
                        normalized[1] + normalized));
                    append_unique(Result,
                        transform_pinyinjiajia_code('o' + normalized));
                end
                else
                begin
                    for source in sources do
                    begin
                        append_unique(Result,
                            transform_pinyinjiajia_code(source));
                    end;
                end;
            end;
        pis_zhinengabc_shuangpin:
            begin
                for source in sources do
                begin
                    append_unique(Result, transform_zhinengabc_code(source));
                end;
            end;
    end;
end;

function nc_get_shuangpin_syllables: TArray<string>;
begin
    Result := Copy(g_syllables);
end;

procedure add_preferred_code(const code_map: TDictionary<string, string>;
    const code: string; const syllable: string);
var
    current: string;
begin
    if (code = '') or (Length(code) > 2) then
    begin
        Exit;
    end;
    if not code_map.TryGetValue(code, current) then
    begin
        code_map.Add(code, syllable);
        Exit;
    end;

    // Valid syllables can share one code: lo/luo in every scheme; ng with
    // neng, niang (Ziguang), or nang (Pinyin Jiajia); hm/hun in Ziguang and
    // hm/hui in Zhineng ABC.
    // Prefer the productive longer syllable while retaining all other codes.
    if Length(syllable) > Length(current) then
    begin
        code_map.AddOrSetValue(code, syllable);
    end;
end;

procedure initialize_maps;
var
    list: TStringList;
    scheme: TncPinyinInputScheme;
    codes: TArray<string>;
    code: string;
    syllable: string;
    idx: Integer;
    code_map: TDictionary<string, string>;
begin
    list := TStringList.Create;
    try
        list.StrictDelimiter := True;
        list.Delimiter := ' ';
        list.DelimitedText := c_pinyin_syllables;
        SetLength(g_syllables, list.Count);
        for idx := 0 to list.Count - 1 do
        begin
            g_syllables[idx] := list[idx];
        end;
    finally
        list.Free;
    end;

    g_microsoft_codes := TDictionary<string, string>.Create;
    g_xiaohe_codes := TDictionary<string, string>.Create;
    g_ziranma_codes := TDictionary<string, string>.Create;
    g_sogou_codes := TDictionary<string, string>.Create;
    g_ziguang_codes := TDictionary<string, string>.Create;
    g_pinyinjiajia_codes := TDictionary<string, string>.Create;
    g_zhinengabc_codes := TDictionary<string, string>.Create;
    for scheme := pis_microsoft_shuangpin to High(TncPinyinInputScheme) do
    begin
        case scheme of
            pis_microsoft_shuangpin:
                code_map := g_microsoft_codes;
            pis_xiaohe_shuangpin:
                code_map := g_xiaohe_codes;
            pis_ziranma_shuangpin:
                code_map := g_ziranma_codes;
            pis_sogou_shuangpin:
                code_map := g_sogou_codes;
            pis_ziguang_shuangpin:
                code_map := g_ziguang_codes;
            pis_zhinengabc_shuangpin:
                code_map := g_zhinengabc_codes;
        else
            code_map := g_pinyinjiajia_codes;
        end;
        for syllable in g_syllables do
        begin
            codes := nc_get_shuangpin_codes(scheme, syllable);
            for code in codes do
            begin
                add_preferred_code(code_map, code, syllable);
            end;
        end;
    end;
end;

function expand_pending_initial(const scheme: TncPinyinInputScheme;
    const value: Char): string;
begin
    case scheme of
        pis_ziguang_shuangpin:
            case value of
                'u': Result := 'zh';
                'a': Result := 'ch';
                'i': Result := 'sh';
            else
                Result := value;
            end;
        pis_pinyinjiajia_shuangpin:
            case value of
                'v': Result := 'zh';
                'u': Result := 'ch';
                'i': Result := 'sh';
            else
                Result := value;
            end;
        pis_zhinengabc_shuangpin:
            case value of
                'a': Result := 'zh';
                'e': Result := 'ch';
                'v': Result := 'sh';
            else
                Result := value;
            end;
    else
        case value of
            'v': Result := 'zh';
            'i': Result := 'ch';
            'u': Result := 'sh';
        else
            Result := value;
        end;
    end;
end;

function parsed_units_match(const parser: TncPinyinParser; const text: string;
    const units: TArray<TncShuangpinDecodedUnit>; const count: Integer): Boolean;
var
    parsed: TncPinyinParseResult;
    idx: Integer;
begin
    Result := False;
    parsed := parser.parse(text);
    if Length(parsed) <> count then
    begin
        Exit;
    end;
    for idx := 0 to count - 1 do
    begin
        if not SameText(parsed[idx].text, units[idx].pinyin) then
        begin
            Exit;
        end;
    end;
    Result := True;
end;

function nc_decode_shuangpin(const scheme: TncPinyinInputScheme;
    const raw_text: string): TncShuangpinDecodeResult;
var
    code_map: TDictionary<string, string>;
    normalized_raw: string;
    idx: Integer;
    start_idx: Integer;
    unit_value: TncShuangpinDecodedUnit;
    code: string;
    canonical_candidate: string;
    boundary_pending: Boolean;
    unit_count: Integer;
    parser: TncPinyinParser;
begin
    Result.raw_text := raw_text;
    Result.canonical_text := '';
    Result.compact_pinyin := '';
    SetLength(Result.units, 0);
    Result.valid := nc_is_shuangpin_scheme(scheme);
    Result.has_pending_key := False;
    if not Result.valid then
    begin
        Result.canonical_text := raw_text;
        Result.compact_pinyin := LowerCase(StringReplace(raw_text, '''', '', [rfReplaceAll]));
        Exit;
    end;

    case scheme of
        pis_microsoft_shuangpin:
            code_map := g_microsoft_codes;
        pis_xiaohe_shuangpin:
            code_map := g_xiaohe_codes;
        pis_ziranma_shuangpin:
            code_map := g_ziranma_codes;
        pis_sogou_shuangpin:
            code_map := g_sogou_codes;
        pis_ziguang_shuangpin:
            code_map := g_ziguang_codes;
        pis_zhinengabc_shuangpin:
            code_map := g_zhinengabc_codes;
    else
        code_map := g_pinyinjiajia_codes;
    end;

    normalized_raw := LowerCase(raw_text);
    idx := 1;
    boundary_pending := False;
    parser := TncPinyinParser.Create;
    try
        while idx <= Length(normalized_raw) do
        begin
            if normalized_raw[idx] = '''' then
            begin
                boundary_pending := Length(Result.units) > 0;
                Inc(idx);
                Continue;
            end;

            start_idx := idx;
            code := normalized_raw[idx];
            Inc(idx);
            if (idx <= Length(normalized_raw)) and (normalized_raw[idx] <> '''') then
            begin
                code := code + normalized_raw[idx];
                Inc(idx);
            end;

            unit_value.raw_text := Copy(raw_text, start_idx, Length(code));
            unit_value.raw_start := start_idx;
            unit_value.raw_length := Length(code);
            unit_value.force_boundary_before := boundary_pending;
            boundary_pending := False;
            unit_value.complete := code_map.TryGetValue(code, unit_value.pinyin);
            if not unit_value.complete then
            begin
                unit_value.pinyin := expand_pending_initial(scheme, code[1]);
                if Length(code) > 1 then
                begin
                    unit_value.pinyin := unit_value.pinyin + code[2];
                    Result.valid := False;
                end
                else
                begin
                    Result.has_pending_key := True;
                end;
            end
            else if Length(code) = 1 then
            begin
                // m/n/o/r are complete marginal syllables, but keeping this flag
                // allows another key to replace the one-key interpretation naturally.
                Result.has_pending_key := True;
            end;

            unit_count := Length(Result.units);
            SetLength(Result.units, unit_count + 1);
            Result.units[unit_count] := unit_value;
            Result.compact_pinyin := Result.compact_pinyin + unit_value.pinyin;

            if Result.canonical_text = '' then
            begin
                Result.canonical_text := unit_value.pinyin;
            end
            else if unit_value.force_boundary_before then
            begin
                Result.canonical_text := Result.canonical_text + '''' + unit_value.pinyin;
            end
            else
            begin
                canonical_candidate := Result.canonical_text + unit_value.pinyin;
                if parsed_units_match(parser, canonical_candidate, Result.units,
                    Length(Result.units)) then
                begin
                    Result.canonical_text := canonical_candidate;
                end
                else
                begin
                    Result.canonical_text := Result.canonical_text + '''' + unit_value.pinyin;
                end;
            end;
        end;
    finally
        parser.Free;
    end;
end;

function nc_shuangpin_raw_prefix_for_units(const decoded: TncShuangpinDecodeResult;
    const unit_count: Integer): string;
var
    end_index: Integer;
begin
    Result := '';
    if (unit_count <= 0) or (Length(decoded.units) = 0) then
    begin
        Exit;
    end;
    if unit_count >= Length(decoded.units) then
    begin
        Exit(decoded.raw_text);
    end;
    end_index := decoded.units[unit_count - 1].raw_start +
        decoded.units[unit_count - 1].raw_length - 1;
    Result := Copy(decoded.raw_text, 1, end_index);
end;

function nc_shuangpin_raw_suffix_after_units(const decoded: TncShuangpinDecodeResult;
    const unit_count: Integer): string;
var
    start_index: Integer;
begin
    if unit_count <= 0 then
    begin
        Exit(decoded.raw_text);
    end;
    if unit_count >= Length(decoded.units) then
    begin
        Exit('');
    end;
    start_index := decoded.units[unit_count].raw_start;
    Result := Copy(decoded.raw_text, start_index,
        Length(decoded.raw_text) - start_index + 1);
end;

function nc_shuangpin_accepts_semicolon(const scheme: TncPinyinInputScheme;
    const raw_text: string): Boolean;
var
    idx: Integer;
    segment_length: Integer;
begin
    if not (scheme in [pis_microsoft_shuangpin, pis_sogou_shuangpin,
        pis_ziguang_shuangpin]) then
    begin
        Exit(False);
    end;
    segment_length := 0;
    for idx := Length(raw_text) downto 1 do
    begin
        if raw_text[idx] = '''' then
        begin
            Break;
        end;
        Inc(segment_length);
    end;
    Result := (segment_length > 0) and Odd(segment_length);
end;

initialization
    initialize_maps;

finalization
    g_zhinengabc_codes.Free;
    g_pinyinjiajia_codes.Free;
    g_ziguang_codes.Free;
    g_sogou_codes.Free;
    g_ziranma_codes.Free;
    g_xiaohe_codes.Free;
    g_microsoft_codes.Free;

end.
