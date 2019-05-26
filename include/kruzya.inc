#if defined _kruzya_included
  #endinput
#endif
#define _kruzya_included

/**
 * Поиск игрока по Account ID.
 *
 * @param   int iAccountID  Steam AccountID пользователя, которого надо найти.
 *
 * @return  int             -1, если не найден. Любое другое число - индекс энтити игрока.
 */
stock int Kruzya_FindClientByAccountID(int iAccountID) {
    int iClient = -1;

    for (int i; ++i <= MaxClients;) {
        if (!IsClientInGame(i) || IsFakeClient(i) || GetSteamAccountID(i) != iAccountID)
            continue;

        iClient = i;
        break;
    }

    return iClient;
}

/**
 * Преобразует три цвета RGB в одно число.
 *
 * @param   int iRed    Красный цвет.
 * @param   int iGreen  Зелёный цвет.
 * @param   int iBlue   Синий цвет.
 *
 * @return  int         Цвет в DEC-виде.
 */
public int Kruzya_RGB2DEC(int iRed, int iGreen, int iBlue) {
    return ((iRed << 16) + (iGreen << 8) + (iBlue));
}

/**
 * Преобразует DEC-вариант цвета в три RGB числа.
 *
 * @param   int iColor  Цвет в DEC-представлении.
 * @param   int iRed    Ссылка на переменную, куда надо записать консинстенцию красного цвета.
 * @param   int iGreen  Ссылка на переменную, куда надо записать консинстенцию зелёного цвета.
 * @param   int iBlue   Ссылка на переменную, куда надо записать консинстенцию синего цвета.
 *
 * @return  void
 */

public void Kruzya_DEC2RGB(int iColor, int &iRed, int &iGreen, int &iBlue) {
    iRed    = (iColor & 0xff0000) >> 16;
    iGreen  = (iColor & 0x00ff00) >> 8;
    iBlue   = (iColor & 0x0000ff);
}

/**
 * Преобразует HEX-строку в DEC представление.
 *
 * @param   char[]  Строка.
 *
 * @return  int     DEC-представление строки.
 */
stock int Kruzya_HEX2DEC(const char[] szHEX) {
    int iResult = 0;

    for (int i; i<strlen(szHEX); i++) {
        char c = szHEX[i];

        if (c >= 48 && c <= 57) {
            c -= 48;
        } else if (c >= 65 && c <= 70) {
            c = (c - 65) + 10;
        } else if (c >= 97 && c <= 102) {
            c = (c - 97) + 10;
        }

        iResult = (iResult << 4) + c;
    }

    return iResult;
}

/**
 * Получает целочисленное значение куки.
 *
 * @param   int     Индекс энтити клиента.
 * @param   Handle  Указатель на куку.
 * @param   int     Дефолтное значение, если значение куки не установлено.
 *
 * @return  int     Значение куки.
 */
stock int Kruzya_GetClientIntCookie(int iClient, Handle hCookie, int iDefault = -1) {
    char szBuffer[13];
    GetClientCookie(iClient, hCookie, szBuffer, sizeof(szBuffer));
    return szBuffer[0] == 0 ? iDefault : StringToInt(szBuffer);
}

/**
 * Устанавливает целочисленное значение куки.
 *
 * @param   int     Индекс энтити клиента.
 * @param   Handle  Указатель на куку.
 * @param   int     Значение куки.
 *
 * @return  void
 */
stock void Kruzya_SetClientIntCookie(int iClient, Handle hCookie, int iValue) {
    char szBuffer[13];
    IntToString(iValue, szBuffer, sizeof(szBuffer));
    SetClientCookie(iClient, hCookie, szBuffer);
}

/**
 * Получает значение куки с плавающей запятой.
 *
 * @param   int     Индекс энтити клиента.
 * @param   Handle  Указатель на куку.
 *
 * @return  float   Значение куки.
 */
stock float Kruzya_GetClientFloatCookie(int iClient, Handle hCookie) {
    char szBuffer[32];
    GetClientCookie(iClient, hCookie, szBuffer, sizeof(szBuffer));
    return StringToFloat(szBuffer);
}

/**
 * Устанавливает значение куки с плавающей запятой.
 *
 * @param   int     Индекс энтити клиента.
 * @param   Handle  Указатель на куку.
 * @param   float   Значение куки.
 *
 * @return  void
 */
stock void Kruzya_SetClientFloatCookie(int iClient, Handle hCookie, float fValue) {
    char szBuffer[32];
    FloatToString(fValue, szBuffer, sizeof(szBuffer));
    SetClientCookie(iClient, hCookie, szBuffer);
} 