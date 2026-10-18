import QtQuick

// Вспомогательный (не singleton) компонент: синхронизация ListModel с
// массивом устройств по ключу.
//
// Зачем не просто `model = newArray`: присваивание нового массива заставляет
// ListView пересоздать ВСЕ делегаты, список мигает и теряет позицию скролла.
// Мы же правим ту же самую ListModel точечно (remove / set / insert / move),
// поэтому существующие делегаты живут, а ScrollBar и текущая прокрутка
// сохраняются.
//
// Ключ сравнения устройств — MAC-адрес: имена могут совпадать или меняться
// (BlueZ подставляет Alias), а адрес уникален и стабилен.
//
// Этот файл — обычный компонент, а не singleton: BluetoothBackend создаёт
// два его экземпляра (для «Сохранённых» и «Новых»). Держать логику здесь, а
// не внутри синглтона, нужно ещё и потому, что функции, объявленные в
// Component, не становятся частью публичного API бэкенда.
QtObject {
    id: root

    // Список вида ListModel {}, которым владеет вызывающая сторона.
    property var model: null
    // Функция, возвращающая ключ элемента. По умолчанию — address.
    property var keyOf: (item) => item.address
    // Компаратор сортировки (a, b) -> number.
    property var compare: null

    // Синхронизирует model с items.
    //
    //   * лишние элементы удаляются;
    //   * у существующих обновляются свойства (set в конец — без изменения порядка);
    //   * новые вставляются сразу на своё место по сортировке;
    //   * позиции меняются только там, где порядок реально нарушен, поэтому
    //     соседние элементы не «прыгают» и прокрутка не сбрасывается.
    //
    // Параметр items: массив объектов с полями-ролями модели.
    function sync(items) {
        if (root.model === null)
            return;

        const list = items || [];
        const keyOf = root.keyOf;

        // 1. Удаляем то, что исчезло из источника.
        for (let i = root.model.count - 1; i >= 0; --i) {
            const current = root.model.get(i);
            let found = false;
            for (let j = 0; j < list.length; ++j) {
                if (keyOf(list[j]) === keyOf(current)) {
                    found = true;
                    break;
                }
            }
            if (!found)
                root.model.remove(i);
        }

        // 2. Обновляем / вставляем / расставляем.
        for (let i = 0; i < list.length; ++i) {
            const item = list[i];
            const key = keyOf(item);

            let at = -1;
            for (let j = 0; j < root.model.count; ++j) {
                if (keyOf(root.model.get(j)) === key) {
                    at = j;
                    break;
                }
            }

            // Нет элемента — вставляем на позицию по порядку и идём дальше.
            // insert() на нужное место не двигает остальные строки (ListView
            // анимирует только появление), поэтому это безопасно.
            if (at < 0) {
                root.model.insert(root.orderedIndex(i, list), item);
                continue;
            }

            // set() в конец обновляет данные, не трогая порядок, и, в отличие
            // от setProperty по одному полю, не мигает: Qt перерисовывает
            // делегат один раз и только если значения реально изменились.
            root.model.set(at, item);

            // Двигаем только при нарушении порядка с предыдущим элементом.
            // Проверка на каждом шаге делает функцию устойчивой к тому, что
            // один move сдвигает индексы всех последующих.
            while (at > 0) {
                const previous = root.model.get(at - 1);
                if (root.inOrder(previous, root.model.get(at)))
                    break;
                root.model.move(at, at - 1, 1);
                --at;
            }
        }
    }

    // Индекс, на который нужно вставить items[index], исходя из уже
    // разложенной части модели: идём от конца, пока предыдущий больше.
    function orderedIndex(index, list) {
        let position = root.model.count;
        const item = list[index];
        while (position > 0) {
            const previous = root.model.get(position - 1);
            if (root.compare !== null && root.compare(previous, item) > 0)
                --position;
            else
                break;
        }
        return position;
    }

    // true, если a не должен стоять после b.
    function inOrder(a, b) {
        if (root.compare === null)
            return true;
        return root.compare(a, b) <= 0;
    }
}
