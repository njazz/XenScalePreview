// Wording of the preview page in the user's language. Only the app's own text is translated:
// the document's description, comments and values are always shown exactly as written.
// A table in code (instead of .strings resources) keeps the Quick Look extension free of bundle plumbing,
// so it behaves the same under SwiftPM, the build scripts and Xcode. Keys use {0}, {1} … placeholders.
import Foundation

/// Language of the preview: the first of the user's preferred languages that has a translation, else English.
let uiLanguage: String = {
    for tag in Locale.preferredLanguages {
        let code = tag.lowercased().split(separator: "-").first.map(String.init) ?? "en"
        if ["en", "fr", "it", "de", "es", "ja"].contains(code) { return code }
        if code == "zh" { return "zh-Hans" }   // Traditional-Chinese readers get Simplified rather than English
    }
    return "en"
}()

func tr(_ key: String, _ args: Any...) -> String {
    var s = table[key]?[uiLanguage] ?? table[key]?["en"] ?? key
    for (i, a) in args.enumerated() { s = s.replacingOccurrences(of: "{\(i)}", with: "\(a)") }
    return s
}

/// Singular/plural variant: keys "<key>.one" and "<key>.other" (French counts 0 as singular; Japanese and Chinese use one form).
func trN(_ key: String, _ n: Int, _ args: Any...) -> String {
    let one = n == 1 || (uiLanguage == "fr" && n == 0)
    return tr(key + (one ? ".one" : ".other"), [n] + args)
}

private let table: [String: [String: String]] = [
    "scale.untitled": [
        "en": "Scala scale",
        "fr": "Gamme Scala",
        "it": "Scala musicale (Scala)",
        "de": "Scala-Skala",
        "es": "Escala Scala",
        "ja": "Scala スケール",
        "zh-Hans": "Scala 音阶",
    ],
    "notes.one": [
        "en": "{0} note",
        "fr": "{0} note",
        "it": "{0} nota",
        "de": "{0} Ton",
        "es": "{0} nota",
        "ja": "{0}音",
        "zh-Hans": "{0} 个音",
    ],
    "notes.other": [
        "en": "{0} notes",
        "fr": "{0} notes",
        "it": "{0} note",
        "de": "{0} Töne",
        "es": "{0} notas",
        "ja": "{0}音",
        "zh-Hans": "{0} 个音",
    ],
    "noteWord.one": [
        "en": "note",
        "fr": "note",
        "it": "nota",
        "de": "Ton",
        "es": "nota",
        "ja": "音",
        "zh-Hans": "音",
    ],
    "noteWord.other": [
        "en": "notes",
        "fr": "notes",
        "it": "note",
        "de": "Töne",
        "es": "notas",
        "ja": "音",
        "zh-Hans": "音",
    ],
    "period": [
        "en": "period {0} ¢",
        "fr": "période {0} ¢",
        "it": "periodo {0} ¢",
        "de": "Periode {0} ¢",
        "es": "periodo {0} ¢",
        "ja": "周期 {0} ¢",
        "zh-Hans": "周期 {0} ¢",
    ],
    "equalOctave": [
        "en": "{0} equal divisions of the octave",
        "fr": "{0} divisions égales de l’octave",
        "it": "{0} divisioni uguali dell’ottava",
        "de": "{0} gleiche Teilungen der Oktave",
        "es": "{0} divisiones iguales de la octava",
        "ja": "オクターブを {0} 等分",
        "zh-Hans": "八度 {0} 等分",
    ],
    "equalPeriod": [
        "en": "{0} equal steps of the period",
        "fr": "{0} pas égaux de la période",
        "it": "{0} passi uguali del periodo",
        "de": "{0} gleiche Schritte der Periode",
        "es": "{0} pasos iguales del periodo",
        "ja": "周期を {0} 等分",
        "zh-Hans": "周期 {0} 等分",
    ],
    "step": [
        "en": "step {0} ¢",
        "fr": "pas {0} ¢",
        "it": "passo {0} ¢",
        "de": "Schritt {0} ¢",
        "es": "paso {0} ¢",
        "ja": "ステップ {0} ¢",
        "zh-Hans": "步长 {0} ¢",
    ],
    "steps": [
        "en": "steps {0}–{1} ¢",
        "fr": "pas {0}–{1} ¢",
        "it": "passi {0}–{1} ¢",
        "de": "Schritte {0}–{1} ¢",
        "es": "pasos {0}–{1} ¢",
        "ja": "ステップ {0}–{1} ¢",
        "zh-Hans": "步长 {0}–{1} ¢",
    ],
    "notAscending": [
        "en": "not in ascending order",
        "fr": "pas en ordre croissant",
        "it": "non in ordine crescente",
        "de": "nicht aufsteigend",
        "es": "no está en orden ascendente",
        "ja": "昇順ではありません",
        "zh-Hans": "未按升序排列",
    ],
    "declared": [
        "en": "{0} declared",
        "fr": "{0} déclarées",
        "it": "{0} dichiarate",
        "de": "{0} angegeben",
        "es": "{0} declaradas",
        "ja": "宣言数 {0}",
        "zh-Hans": "声明 {0} 个",
    ],
    "noDescription": [
        "en": "No description",
        "fr": "Aucune description",
        "it": "Nessuna descrizione",
        "de": "Keine Beschreibung",
        "es": "Sin descripción",
        "ja": "説明なし",
        "zh-Hans": "无说明",
    ],
    "onePeriod": [
        "en": "One period",
        "fr": "Une période",
        "it": "Un periodo",
        "de": "Eine Periode",
        "es": "Un periodo",
        "ja": "1周期",
        "zh-Hans": "一个周期",
    ],
    "degrees": [
        "en": "Degrees",
        "fr": "Degrés",
        "it": "Gradi",
        "de": "Stufen",
        "es": "Grados",
        "ja": "音度",
        "zh-Hans": "音级",
    ],
    "source": [
        "en": "Source",
        "fr": "Source",
        "it": "Sorgente",
        "de": "Quelltext",
        "es": "Origen",
        "ja": "ソース",
        "zh-Hans": "源文件",
    ],
    "lines.one": [
        "en": "{0} line",
        "fr": "{0} ligne",
        "it": "{0} riga",
        "de": "{0} Zeile",
        "es": "{0} línea",
        "ja": "{0} 行",
        "zh-Hans": "{0} 行",
    ],
    "lines.other": [
        "en": "{0} lines",
        "fr": "{0} lignes",
        "it": "{0} righe",
        "de": "{0} Zeilen",
        "es": "{0} líneas",
        "ja": "{0} 行",
        "zh-Hans": "{0} 行",
    ],
    "col.value": [
        "en": "Value",
        "fr": "Valeur",
        "it": "Valore",
        "de": "Wert",
        "es": "Valor",
        "ja": "値",
        "zh-Hans": "值",
    ],
    "col.cents": [
        "en": "Cents",
        "fr": "Cents",
        "it": "Cent",
        "de": "Cent",
        "es": "Cents",
        "ja": "セント",
        "zh-Hans": "音分",
    ],
    "col.step": [
        "en": "Step",
        "fr": "Pas",
        "it": "Passo",
        "de": "Schritt",
        "es": "Paso",
        "ja": "ステップ",
        "zh-Hans": "步长",
    ],
    "col.nearest": [
        "en": "Nearest 12-TET",
        "fr": "12-TET le plus proche",
        "it": "12-TET più vicino",
        "de": "Nächster 12-TET-Ton",
        "es": "12-TET más cercano",
        "ja": "最も近い12平均律",
        "zh-Hans": "最接近的十二平均律",
    ],
    "tip": [
        "en": "Degree {0} · {1} · {2} ¢ · {3}",
        "fr": "Degré {0} · {1} · {2} ¢ · {3}",
        "it": "Grado {0} · {1} · {2} ¢ · {3}",
        "de": "Stufe {0} · {1} · {2} ¢ · {3}",
        "es": "Grado {0} · {1} · {2} ¢ · {3}",
        "ja": "音度 {0} · {1} · {2} ¢ · {3}",
        "zh-Hans": "音级 {0} · {1} · {2} ¢ · {3}",
    ],
    "err.tooLarge": [
        "en": "The file is too large to preview ({0} MB).",
        "fr": "Le fichier est trop volumineux pour être prévisualisé ({0} Mo).",
        "it": "Il file è troppo grande per l’anteprima ({0} MB).",
        "de": "Die Datei ist zu groß für die Vorschau ({0} MB).",
        "es": "El archivo es demasiado grande para la vista previa ({0} MB).",
        "ja": "ファイルが大きすぎてプレビューできません（{0} MB）。",
        "zh-Hans": "文件太大，无法预览（{0} MB）。",
    ],
    "err.expectCount": [
        "en": "Line {0}: expected the number of notes, found “{1}”.",
        "fr": "Ligne {0} : nombre de notes attendu, « {1} » trouvé.",
        "it": "Riga {0}: era atteso il numero di note, trovato “{1}”.",
        "de": "Zeile {0}: Anzahl der Töne erwartet, gefunden: „{1}“.",
        "es": "Línea {0}: se esperaba el número de notas, pero se encontró «{1}».",
        "ja": "{0} 行目: 音の数が必要ですが「{1}」が見つかりました。",
        "zh-Hans": "第 {0} 行：应为音的数量，实际为“{1}”。",
    ],
    "err.badPitch": [
        "en": "Line {0}: “{1}” is not a ratio or a cents value.",
        "fr": "Ligne {0} : « {1} » n’est ni un rapport ni une valeur en cents.",
        "it": "Riga {0}: “{1}” non è un rapporto né un valore in cent.",
        "de": "Zeile {0}: „{1}“ ist weder ein Verhältnis noch ein Cent-Wert.",
        "es": "Línea {0}: «{1}» no es una razón ni un valor en cents.",
        "ja": "{0} 行目: 「{1}」は比でもセント値でもありません。",
        "zh-Hans": "第 {0} 行：“{1}”不是比值或音分值。",
    ],
    "err.empty": [
        "en": "The file is empty.",
        "fr": "Le fichier est vide.",
        "it": "Il file è vuoto.",
        "de": "Die Datei ist leer.",
        "es": "El archivo está vacío.",
        "ja": "ファイルが空です。",
        "zh-Hans": "文件为空。",
    ],
    "err.noCount": [
        "en": "The number of notes is missing.",
        "fr": "Le nombre de notes est manquant.",
        "it": "Manca il numero di note.",
        "de": "Die Anzahl der Töne fehlt.",
        "es": "Falta el número de notas.",
        "ja": "音の数がありません。",
        "zh-Hans": "缺少音的数量。",
    ],
    "err.short": [
        "en": "The file lists {0} notes but only {1} were found.",
        "fr": "Le fichier annonce {0} notes mais seulement {1} ont été trouvées.",
        "it": "Il file dichiara {0} note ma ne sono state trovate solo {1}.",
        "de": "Die Datei nennt {0} Töne, gefunden wurden aber nur {1}.",
        "es": "El archivo indica {0} notas pero solo se encontraron {1}.",
        "ja": "ファイルには {0} 個の音が宣言されていますが、{1} 個しか見つかりませんでした。",
        "zh-Hans": "文件声明了 {0} 个音，但只找到 {1} 个。",
    ],
]
