#!/bin/sh

# 1. Проверка аргумента
if [ -z "$1" ]; then
    echo "Ошибка: Файл не указан." >&2
    echo "Использование: $0 <исходный_файл>" >&2
    exit 2
fi

SRC_FILE="$1"

if [ ! -r "$SRC_FILE" ]; then
    echo "Ошибка: Файл '$SRC_FILE' не существует или недоступен для чтения." >&2
    exit 3
fi

# Получаем абсолютный (полный) путь к папке, чтобы cd внутри скрипта его не сломал
SRC_DIR=$(cd "$(dirname "$SRC_FILE")" && pwd)
SRC_BASE=$(basename "$SRC_FILE")

# 2. Поиск ключевого слова "Output:"
OUT_NAME=$(sed -n -e 's/.*Output:[[:space:]]*\([^[:space:]]*\).*/\1/p' "$SRC_FILE")

if [ -z "$OUT_NAME" ]; then
    echo "Ошибка: Комментарий 'Output:' не найден в файле." >&2
    exit 4
fi

# 3. Создание временной папки
TMP_DIR=$(mktemp -d)
if [ ! -d "$TMP_DIR" ]; then
    echo "Ошибка: Не удалось создать временную папку." >&2
    exit 5
fi

# 4. Функция автоматической очистки (Обработка сигналов через trap)
clean_up() {
    rc=$?
    trap - EXIT HUP INT QUIT TERM
    if [ -d "$TMP_DIR" ]; then
        rm -rf "$TMP_DIR"
    fi
    exit $rc
}
trap clean_up EXIT HUP INT QUIT TERM

# 5. Копирование и компиляция во временной папке
cp "$SRC_FILE" "$TMP_DIR/$SRC_BASE"
cd "$TMP_DIR" || exit 6

case "$SRC_BASE" in
    *.c)   gcc -O2 "$SRC_BASE" -o "$OUT_NAME" ;;
    *.cpp|*.cc) g++ -O2 "$SRC_BASE" -o "$OUT_NAME" ;;
    *.tex) pdflatex -interaction=nonstopmode "$SRC_BASE" ;;
    *) echo "Ошибка: Неподдерживаемое расширение (.c, .cpp, .tex)." >&2 ; exit 7 ;;
esac

if [ $? -ne 0 ]; then
    echo "Ошибка: Компиляция завершилась сбоем." >&2
    exit 1
fi

# 6. Возврат готового скомпилированного файла в исходную папку
if [ -f "$OUT_NAME" ]; then
    cp "$OUT_NAME" "$SRC_DIR/$OUT_NAME"
else
    echo "Ошибка: Итоговый файл не был создан." >&2
    exit 8
fi

echo "Успех! Файл создан: $SRC_DIR/$OUT_NAME"
