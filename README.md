# murder-confirmed
This mode was copied from the 2019 Call of Duty Modern Warfare game. Its essence is to kill the enemy and collect after the death of his army token (unfortunately, he could not take out the token model from the deck). When you set a certain number of tokens, some team wins and gets buns in the form of Anew bonuses and experience points.  When the team wins, an itd window pops up with the winner (an analogue of the GunGame window.) There is also a HARDCORE mode. In this mode, all HP drops to 25 and Friendly Fire turns on.

Папку style поместить на ваш Web-сервер
В исходнике 8 строка STYLES_URL, изменить на свой адрес
Скомпилируйте плагин
Скопируйте скомпилированный .amxx в директорию /amxmodx/plugins/
Пропишите .amxx в файле /amxmodx/configs/plugins.ini
Залить файлы и папки через FTP согласно иерархии в архиве
Смените карту или перезапустите сервер.

Настройки	
Плагин обладает навыками самостоятельного создания cfg файла по адресу [code] /cstrike/addons/amxmodx/configs/plugins/murder_confirmed.cfg [/code] 

Код:
`// This file was auto-generated by AMX Mod X (v1.9.0.5271)
// Cvars for plugin "Murder Confirmed" by "maFFyoZZyk" (murder_confirmed.amxx, v1.1)

// Выбор мода. 0 - вызвать меню во время игры. 1 - Обычный режим. 2 - Режим ХАРДКОР.
// -
// Default: "0"
// Minimum: "0.000000"
mc_mp_mode "0"

// Сколько жетонов нужно собрать для победы
// -
// Default: "100"
// Minimum: "0.000000"
mc_max_score "100"

// Бесконечный раунд
// -
// Default: "aef"
mc_mp_infinite "aef"

// Запрет выдачи бомбы
// -
// Default: "0"
// Minimum: "0.000000"
mc_mp_give_c4 "0"

// Бесконечное пополнение патронов
// -
// Default: "2"
// Minimum: "0.000000"
mc_mp_inf_ammo "2"

// Время,через которое будут удаляться item'ы (Оружия),дропнутые игроком
// -
// Default: "2"
// Minimum: "0.000000"
mc_mp_stime "2"

// Автоматический респавн игрока после смерти
// -
// Default: "0.3"
// Minimum: "0.000000"
mc_mp_forcerspawn "0.3"

// Выдача основного оружия террористам
// -
// Default: "ak47"
mc_mp_t_wp_primary "ak47"

// Выдача запасного оружия террористам
// -
// Default: "deagle"
mc_mp_t_wp_secondary "deagle"

// Выдача основного оружия контр - террористам
// -
// Default: "m4a1"
mc_mp_ct_wp_primary "m4a1"

// Выдача запасного оружия контр - террористам
// -
// Default: "deagle"
mc_mp_ct_wp_secondary "deagle"

// Указывает время защиты игрока после респауна (в секундах).
// -
// Default: "2.0"
// Minimum: "0.000000"
mc_mp_spawnprotectiontime "2.0"

// Через какое время жетон исчезнет
// -
// Default: "5.0"
// Minimum: "0.000000"
mc_mp_live_mdl "5.0"

// Звук при исчезании жетона
// -
// Default: "1"
// Minimum: "0.000000"
mc_mp_snd_delete "1"

// Сколько ХП у игрока(Режим ХАРДКОР)
// -
// Default: "25.0"
// Minimum: "0.000000"
mc_mp_live_user "25.0"

// Урон наносимый союзнику 1.0 = урон врагу (Режим ХАРДКОР)
// -
// Default: "1.0"
// Minimum: "0.000000"
mc_mp_bullets_dmg "1.0"

// Урон наносимый союзнику гранатой 1.0 = урон врагу (Режим ХАРДКОР)
// -
// Default: "1.0"
// Minimum: "0.000000"
mc_mp_grenade_dmg "1.0"

// Другой урон наносимый союзнику 1.0 = урон врагу (Режим ХАРДКОР)
// -
// Default: "1.0"
// Minimum: "0.000000"
mc_mp_other_dmg "1.0"

// Сколько бонусов выдавать победившей команде
// -
// Default: "1"
// Minimum: "0.000000"
mc_mp_bonus_for_winteam "1"

// Сколько опыта выдавать победившей команде
// -
// Default: "5.0"
// Minimum: "0.000000"
mc_mp_exp_for_winteam "5.0"

// Сколько бонусов забирать у проигравшей команды
// -
// Default: "1"
// Minimum: "0.000000"
mc_mp_withdrawing_bonus_losers "1"

// Сколько опыта забирать у проигравшей команды
// -
// Default: "5.0"
// Minimum: "0.000000"
mc_mp_withdrawing_exp_losers "5.0"`

В исходнике устанавливаем префиксы для работы плагина (84 строка)

`new g_szMapPrefixes[][] = // Список префиксов карт, где плагин будет работать
{
    "$",
    "fy_"
};`

В исходнике снять комментирование, если у вас DM сервер(8 строка)
<code> //#define CSDM // Раскоментировать, если у вас режим CSDM </code>
В исходнике устанавливаем ссылку со стилем MOTD (10 строка)
<code>new const STYLES_URL[] = "http://gfsoul.csmix.ru/style";, где http://gfsoul.csmix.ru/ - ваш сайт</code>

По пути <code>/cstrike/addons/amxmodx/configs/tokenwpremover</code>

Создаем файлы согласно названию карт, если нужна настройка удаления оружия с карт для каждой свое, по умолчанию используется файл default.ini
