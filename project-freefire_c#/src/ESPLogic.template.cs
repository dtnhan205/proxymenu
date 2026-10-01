using System;
using System.Collections;
using System.IO;
using COW;
using COW.GamePlay;
using UnityEngine;

namespace ProjectEspPatch
{
    public static class Logic
    {
        private const int EspMaster = 1;
        private const int EspBox = 2;
        private const int EspTracer = 4;
        private const int EspHealth = 8;
        private const int EspName = 16;
        private const int EspDistance = 32;
        private const int EspFov = 64;
        private const int EspMask = 127;

        private const int StateInitialized = 128;
        private const int StateThreeFinger = 256;
        private const int StateDragging = 512;
        private const int TabShift = 10;
        private const int TabMask = 3072;
        private const int TapShift = 12;
        private const int TapMask = 12288;
        private const int AimEnabled = 16384;
        private const int AimModeShift = 15;
        private const int AimModeMask = 98304;
        private const int NoRecoil = 131072;
        private const int HeadRateShift = 18;
        private const int HeadRateMask = 1835008;
        private const int AimSystemEnabled = 2097152;
        private const int AimSystemHead = 4194304;
        private const int StateAuthorized = 8388608;
        private const int AimActionSilentToggle = 1;
        private const int AimActionSystemToggle = 2;
        private const int AimActionSilentTarget = 3;
        private const int AimActionHeadRate = 4;
        private const int AimActionFov = 5;
        private const int AimActionSystemTarget = 6;
        private const int AimActionNoRecoil = 7;
        private const int AimActionFovSize = 8;
        private const int AimActionFovColor = 9;
        private const int ModalNone = 0;
        private const int ModalAimMode = 10;
        private const int ModalHeadRate = 20;
        private const int ModalFovSize = 30;
        private const int ModalSystemTarget = 40;
        private const int ModalTracerOrigin = 50;
        private const int ModalFovColor = 60;
        private const int VipFastFire = 1;
        private const int VipHeadDamage = 4;
        private const int VipWideView = 8;
        private const int AuxFastParachute = 1;
        private const int AuxSpeedRunning = 2;
        private const int AuxSpeedRunningApplied = 4;
        private const int AuxMask = 7;
        private const int AuxTickShift = 3;
        private const float AuxStateMarker = 1000000f;
        private const ulong SpeedRunningKey = 4995421289296778564UL;
        private const int DefaultAimState = AimEnabled | (2 << AimModeShift)
            | (3 << HeadRateShift);

        public static bool Bootstrap(Player self)
        {
            if (self == null)
            {
                return false;
            }
            try
            {
                bool stealth = self.IsInStealth();
                if (!self.IsLocalPlayer())
                {
                    return stealth;
                }

                GameObject driver = GameObject.Find("__esp_driver");
                if (driver == null)
                {
                    Camera camera = Camera.main;
                    Transform legacyFov = camera == null
                        ? null
                        : camera.transform.Find("__esp_fov");
                    if (legacyFov != null)
                    {
                        UnityEngine.Object.Destroy(legacyFov.gameObject);
                    }
                    driver = new GameObject("__esp_driver");
                    driver.transform.localScale = new Vector3(0f, (float)(1 | (1 << 19) | (0 << 3) | (245 << 11)), (float)(255 << 4));
                    driver.transform.position = new Vector3(Time.unscaledTime, 85f, 140f);
                    SceneEditBoxSelectTool tool = (SceneEditBoxSelectTool)driver.AddComponent(typeof(SceneEditBoxSelectTool));
                    if (tool != null)
                    {
                        UnityEngine.Object.DontDestroyOnLoad(driver);
                    }
                }
                else if (driver.transform.position.z < 10f)
                {
                    driver.transform.position = new Vector3(driver.transform.position.x, 85f, 140f);
                }
                return stealth;
            }
            catch (Exception)
            {
                return false;
            }
        }

        public static void Draw(SceneEditBoxSelectTool self)
        {
            if (self == null)
            {
                return;
            }
            Event currentEvent = Event.current;
            if (currentEvent == null)
            {
                return;
            }

            GameObject driverObject = self.gameObject;
            if (driverObject == null || driverObject.name != "__esp_driver")
            {
                return;
            }

            Transform oldLogHolder = driverObject.transform.Find("__esp_log_holder");
            if (oldLogHolder != null)
            {
                UnityEngine.Object.Destroy(oldLogHolder.gameObject);
            }

            Vector3 driverPos = driverObject.transform.position;
            float fovRadius = (driverPos.z >= 10f && driverPos.z <= 600f) ? driverPos.z : 140f;
            driverPos.z = fovRadius;
            float customCamFov = (driverPos.y >= 50f && driverPos.y <= 140f) ? driverPos.y : 85f;
            driverPos.y = customCamFov;
            Vector3 modalState = driverObject.transform.localScale;
            int activeModal = (int)modalState.x;
            if (activeModal != ModalAimMode && activeModal != ModalHeadRate
                && activeModal != ModalFovSize && activeModal != ModalSystemTarget
                && activeModal != ModalTracerOrigin && activeModal != ModalFovColor)
            {
                activeModal = ModalNone;
            }
            int rawModalY = (int)modalState.y;
            int tracerOriginVal = rawModalY & 3;
            if (tracerOriginVal < 1) tracerOriginVal = 1;
            bool isBottomTracer = (tracerOriginVal == 2);
            bool isRainbow = (rawModalY & 4) != 0;
            int customR;
            int customG;
            int customB;
            if ((rawModalY & (1 << 19)) == 0)
            {
                customR = 0;
                customG = 245;
                customB = 255;
                isRainbow = false;
            }
            else
            {
                customR = (rawModalY >> 3) & 255;
                customG = (rawModalY >> 11) & 255;
                customB = ((int)modalState.z >> 4) & 255;
            }
            int vipMask = (int)modalState.z & 15;

            int screenWidth = Screen.width;
            int screenHeight = Screen.height;
            float panelWidth = Mathf.Clamp((float)screenWidth * 0.35f, 380f, 460f);
            float panelHeight = Mathf.Clamp((float)screenHeight * 0.84f, 480f, (float)screenHeight - 24f);
            int state = (int)self.{{SCENE_STATE_FIELD}}.x;
            bool menuOpen = self.{{SCENE_MENU_FIELD}};

            if ((state & StateInitialized) == 0)
            {
                state = StateInitialized | EspMask | DefaultAimState | StateAuthorized;
                self.{{SCENE_POSITION_FIELD}} = new Vector2(
                    ((float)screenWidth - panelWidth) * 0.5f,
                    ((float)screenHeight - panelHeight) * 0.5f);
                self.{{SCENE_STATE_FIELD}} = new Vector2((float)state, 0f);
                menuOpen = false;
                self.{{SCENE_MENU_FIELD}} = false;
                vipMask = 0;
                modalState = new Vector3(0f, (float)(1 | (1 << 19) | (0 << 3) | (245 << 11)), (float)(255 << 4));
                driverObject.transform.localScale = modalState;
            }

            int curFrame = Time.frameCount;

            // Dá»n dáº¹p RAM / GC Ä‘á»‹nh ká»³ 15 giÃ¢y 1 láº§n (~900 frames á»Ÿ 60fps) Ä‘á»ƒ giáº£i phÃ³ng bá»™ nhá»›, tá»‘i Æ°u FPS vÃ  chá»‘ng trÃ n RAM
            float nowTime = Time.unscaledTime;
            if (nowTime - driverPos.x >= 15f || (curFrame % 900 == 1 && nowTime - driverPos.x >= 10f))
            {
                driverPos.x = nowTime;
                driverObject.transform.position = driverPos;
                GC.Collect();
            }

            float encodedAuxState = self.{{SCENE_STATE_FIELD}}.y;
            int auxState;
            int lastTapTick;
            if (encodedAuxState <= -AuxStateMarker)
            {
                int packedAuxState = (int)(-encodedAuxState - AuxStateMarker);
                auxState = packedAuxState & AuxMask;
                lastTapTick = packedAuxState >> AuxTickShift;
            }
            else
            {
                auxState = 0;
                lastTapTick = (int)(Mathf.Abs(encodedAuxState) * 4f);
            }

            // Remote config sync from AppNew (Clipboard IPC + multi-path menu_config.json sync)
            if (curFrame < 120 || curFrame % 3 == 0)
            {
                try
                {
                    string cJson = null;

                    // Direct multi-path file sync with FileShare.ReadWrite (Silent, zero iOS pasteboard alerts)
                    string cfgPath = null;
                    string cfgFile = "/menu_config.json";
                    string pDir = Application.persistentDataPath;
                    if (!string.IsNullOrEmpty(pDir) && (pDir.EndsWith("/") || pDir.EndsWith("\\")))
                    {
                        pDir = pDir.Substring(0, pDir.Length - 1);
                    }

                    string[] searchPaths = new string[] {
                        pDir + cfgFile,
                        pDir + "/IFix" + cfgFile,
                        pDir + "/Documents" + cfgFile,
                        pDir + "/../Documents" + cfgFile,
                        pDir + "/../Library/Caches" + cfgFile,
                        pDir + "/../tmp" + cfgFile,
                        "/var/mobile/Downloads" + cfgFile,
                        "/tmp" + cfgFile,
                        "/private/var/tmp" + cfgFile
                    };

                    for (int sp = 0; sp < searchPaths.Length; sp++)
                    {
                        string spath = searchPaths[sp];
                        if (!string.IsNullOrEmpty(spath) && File.Exists(spath))
                        {
                            cfgPath = spath;
                            break;
                        }
                    }

                    if (!string.IsNullOrEmpty(cfgPath) && File.Exists(cfgPath))
                    {
                        try
                        {
                            FileStream fs = new FileStream(cfgPath, FileMode.Open, FileAccess.Read, FileShare.ReadWrite);
                            StreamReader sr = new StreamReader(fs, System.Text.Encoding.UTF8);
                            cJson = sr.ReadToEnd();
                            sr.Close();
                            fs.Close();
                        }
                        catch (Exception)
                        {
                            try
                            {
                                cJson = File.ReadAllText(cfgPath);
                            }
                            catch (Exception)
                            {
                            }
                        }
                    }

                    if (!string.IsNullOrEmpty(cJson))
                    {
                        cJson = cJson.Trim();
                        if (!cJson.Contains("\"box_esp\""))
                        {
                            try
                            {
                                string b64Str = cJson;
                                int pData = cJson.IndexOf("\"data\":");
                                if (pData >= 0)
                                {
                                    int sQ = cJson.IndexOf('"', pData + 7);
                                    if (sQ >= 0)
                                    {
                                        int eQ = cJson.IndexOf('"', sQ + 1);
                                        if (eQ > sQ) b64Str = cJson.Substring(sQ + 1, eQ - sQ - 1);
                                    }
                                }
                                byte[] encBytes = Convert.FromBase64String(b64Str);
                                byte[] xKey = new byte[16];
                                xKey[0] = 75;
                                xKey[1] = 158;
                                xKey[2] = 51;
                                xKey[3] = 127;
                                xKey[4] = 26;
                                xKey[5] = 136;
                                xKey[6] = 210;
                                xKey[7] = 101;
                                xKey[8] = 12;
                                xKey[9] = 241;
                                xKey[10] = 84;
                                xKey[11] = 155;
                                xKey[12] = 39;
                                xKey[13] = 234;
                                xKey[14] = 99;
                                xKey[15] = 24;
                                for (int i = 0; i < encBytes.Length; i++)
                                {
                                    encBytes[i] = (byte)(encBytes[i] ^ xKey[i % 16]);
                                }
                                cJson = System.Text.Encoding.UTF8.GetString(encBytes);
                            }
                            catch
                            {
                            }
                        }

                            state |= StateAuthorized;

                            int nBox = 1;
                            int nLine = 1;
                            int nHealth = 1;
                            int nName = 1;
                            int nDist = 1;
                            int nSilent = 0;
                            int nBot = 0;
                            int nRecoil = 0;
                            int nFov = (int)fovRadius;
                            int nHead = 2;
                            int nCol = 0;
                            int nTarget = 1; // 1 = Head, 0 = Neck
                            int nBuffDmg = 0;
                            int nFastFire = 0;
                            int nWide = 0;
                            int nCamDist = 85;
                            int nSpeed = 0;
                            int nParachute = 0;
                            int nBoxR = -1;
                            int nBoxG = -1;
                            int nBoxB = -1;
                            int nLineR = -1;
                            int nLineG = -1;
                            int nLineB = -1;

                            string[] cfgKeys = new string[] {
                                "box_esp", "line_esp", "health_bar", "name_tag", "distance_tag",
                                "aim_silent", "aim_bot", "no_recoil", "aim_fov", "headshot_rate", "color",
                                "aim_target", "buff_damage", "fast_fire", "wide_view", "cam_distance",
                                "speed_run", "fast_parachute", "box_r", "box_g", "box_b",
                                "line_r", "line_g", "line_b"
                            };

                            for (int k = 0; k < cfgKeys.Length; k++)
                            {
                                string kName = cfgKeys[k];
                                int pK = cJson.IndexOf("\"" + kName + "\"");
                                if (pK >= 0)
                                {
                                    int cK = cJson.IndexOf(':', pK);
                                    if (cK >= 0)
                                    {
                                        int sK = cK + 1;
                                        while (sK < cJson.Length && (cJson[sK] == ' ' || cJson[sK] == '\t' || cJson[sK] == '"')) sK++;
                                        int eK = sK;
                                        while (eK < cJson.Length && ((cJson[eK] >= '0' && cJson[eK] <= '9') || cJson[eK] == '-')) eK++;
                                        if (eK > sK)
                                        {
                                            int parsedVal = 0;
                                            if (int.TryParse(cJson.Substring(sK, eK - sK), out parsedVal))
                                            {
                                                if (k == 0) nBox = parsedVal;
                                                else if (k == 1) nLine = parsedVal;
                                                else if (k == 2) nHealth = parsedVal;
                                                else if (k == 3) nName = parsedVal;
                                                else if (k == 4) nDist = parsedVal;
                                                else if (k == 5) nSilent = parsedVal;
                                                else if (k == 6) nBot = parsedVal;
                                                else if (k == 7) nRecoil = parsedVal;
                                                else if (k == 8) nFov = parsedVal;
                                                else if (k == 9) nHead = parsedVal;
                                                else if (k == 10) nCol = parsedVal;
                                                else if (k == 11) nTarget = parsedVal;
                                                else if (k == 12) nBuffDmg = parsedVal;
                                                else if (k == 13) nFastFire = parsedVal;
                                                else if (k == 14) nWide = parsedVal;
                                                else if (k == 15) nCamDist = parsedVal;
                                                else if (k == 16) nSpeed = parsedVal;
                                                else if (k == 17) nParachute = parsedVal;
                                                else if (k == 18) nBoxR = parsedVal;
                                                else if (k == 19) nBoxG = parsedVal;
                                                else if (k == 20) nBoxB = parsedVal;
                                                else if (k == 21) nLineR = parsedVal;
                                                else if (k == 22) nLineG = parsedVal;
                                                else if (k == 23) nLineB = parsedVal;
                                            }
                                        }
                                    }
                                }
                            }

                            int newEsp = 0;
                            if (nBox != 0) newEsp |= EspBox;
                            if (nLine != 0) newEsp |= EspTracer;
                            if (nHealth != 0) newEsp |= EspHealth;
                            if (nName != 0) newEsp |= EspName;
                            if (nDist != 0) newEsp |= EspDistance;
                            if (nSilent != 0 || nBot != 0) newEsp |= EspFov;
                            if (newEsp != 0) newEsp |= EspMaster;

                            int newAim = 0;
                            // Aimbot (AimSystemEnabled) có priority cao hơn silent aim
                            // Hai chế độ LOẠI TRỪ lẫn nhau
                            if (nBot != 0)
                            {
                                // Bật aimbot native, tắt hoàn toàn silent aim
                                newAim |= AimSystemEnabled;
                                if (nTarget == 1) newAim |= AimSystemHead;
                                else newAim &= ~AimSystemHead;
                                // Không set AimEnabled kể cả khi nSilent == 1
                            }
                            else if (nSilent != 0)
                            {
                                // Chỉ bật silent aim khi KHÔNG có aimbot
                                newAim |= AimEnabled | (2 << AimModeShift);
                            }
                            if (nRecoil != 0) newAim |= NoRecoil;
                            if (nHead < 0) nHead = 0;
                            if (nHead > 4) nHead = 4;
                            newAim |= (nHead << HeadRateShift);

                            state = (state & (StateInitialized | StateAuthorized)) | newEsp | newAim;

                            if (nCamDist >= 50 && nCamDist <= 140)
                            {
                                customCamFov = (float)nCamDist;
                                driverPos.y = customCamFov;
                                driverObject.transform.position = driverPos;
                            }

                            if (nFastFire != 0) vipMask |= VipFastFire;
                            else vipMask &= ~VipFastFire;

                            if (nBuffDmg != 0) vipMask |= VipHeadDamage;
                            else vipMask &= ~VipHeadDamage;

                            if (nWide != 0) vipMask |= VipWideView;
                            else vipMask &= ~VipWideView;

                            if (nParachute != 0) auxState |= AuxFastParachute;
                            else auxState &= ~AuxFastParachute;

                            if (nSpeed != 0) auxState |= AuxSpeedRunning;
                            else auxState &= ~AuxSpeedRunning;

                            int cfgPackedAux = (lastTapTick << AuxTickShift) | (auxState & AuxMask);
                            self.{{SCENE_STATE_FIELD}} = new Vector2((float)state, -AuxStateMarker - (float)cfgPackedAux);

                            if (nFov >= 10 && nFov <= 600)
                            {
                                fovRadius = (float)nFov;
                                driverPos.z = fovRadius;
                                driverObject.transform.position = driverPos;
                            }

                            int cR = 255, cG = 41, cB = 62; // 0: Äá» Neon
                            // Priority: box_r/g/b > line_r/g/b > color preset
                            if (nBoxR >= 0 && nBoxG >= 0 && nBoxB >= 0)
                            {
                                cR = nBoxR;
                                cG = nBoxG;
                                cB = nBoxB;
                            }
                            else if (nLineR >= 0 && nLineG >= 0 && nLineB >= 0)
                            {
                                cR = nLineR;
                                cG = nLineG;
                                cB = nLineB;
                            }
                            else if (nCol == 1) { cR = 0; cG = 229; cB = 255; }       // Xanh Cyan
                            else if (nCol == 2) { cR = 13; cG = 224; cB = 97; }   // Xanh LÃ¡
                            else if (nCol == 3) { cR = 255; cG = 209; cB = 31; }  // VÃ ng Kim
                            else if (nCol == 4) { cR = 255; cG = 122; cB = 0; }   // Cam Lá»­a
                            else if (nCol == 5) { cR = 157; cG = 0; cB = 255; }   // TÃ­m Neon
                            else if (nCol == 6) { cR = 255; cG = 20; cB = 147; }  // Há»“ng Neon
                            else if (nCol == 7) { cR = 30; cG = 120; cB = 255; }  // Xanh DÆ°Æ¡ng
                            else if (nCol == 8) { cR = 0; cG = 255; cB = 163; }   // Xanh Ngá»c
                            else if (nCol == 9) { cR = 255; cG = 255; cB = 255; } // Tráº¯ng BÄƒng

                            modalState = new Vector3(0f, (float)(1 | (1 << 19) | ((cR & 255) << 3) | ((cG & 255) << 11)), (float)((vipMask & 15) | ((cB & 255) << 4)));
                            driverObject.transform.localScale = modalState;
                        }
                    }
                    catch (Exception)
                    {
                    }
                }

            state |= StateAuthorized;
            self.{{SCENE_STATE_FIELD}} = new Vector2((float)state, self.{{SCENE_STATE_FIELD}}.y);

            int mask = state & EspMask;
            int activeTab = (state & TabMask) >> TabShift;
            if (activeTab > 3)
            {
                activeTab = 0;
            }
            int tapCount = driverObject != null ? (int)driverObject.transform.localEulerAngles.y : 0;
            int aimMode = (state & AimModeMask) >> AimModeShift;
            int headRateIndex = (state & HeadRateMask) >> HeadRateShift;

            if (currentEvent.type == EventType.Repaint)
            {
                bool fourFingerActive = (state & StateThreeFinger) != 0;
                bool fourFingersDown = Input.touchCount >= 4;

                if (fourFingersDown && !fourFingerActive)
                {
                    state |= StateThreeFinger;
                }
                else if (!fourFingersDown && fourFingerActive)
                {
                    state &= ~StateThreeFinger;
                    int nowTick = (int)(Time.unscaledTime * 4f);
                    if (lastTapTick > 0 && nowTick - lastTapTick > 16)
                    {
                        tapCount = 0;
                    }
                    tapCount++;
                    if (tapCount >= 4)
                    {
                        tapCount = 0;
                        menuOpen = false;
                        self.{{SCENE_MENU_FIELD}} = false;
                    }
                    if (driverObject != null)
                    {
                        driverObject.transform.localEulerAngles = new Vector3(
                            driverObject.transform.localEulerAngles.x,
                            (float)tapCount,
                            driverObject.transform.localEulerAngles.z);
                    }
                    state = state & ~TapMask;
                    lastTapTick = nowTick;
                }
            }

            float maxPanelX = (float)screenWidth - panelWidth - 8f;
            float maxPanelY = (float)screenHeight - panelHeight - 8f;
            if (maxPanelX < 8f) maxPanelX = 8f;
            if (maxPanelY < 8f) maxPanelY = 8f;
            float panelX = Mathf.Clamp(self.{{SCENE_POSITION_FIELD}}.x, 8f, maxPanelX);
            float panelY = Mathf.Clamp(self.{{SCENE_POSITION_FIELD}}.y, 8f, maxPanelY);
            if (self.{{SCENE_POSITION_FIELD}}.x != panelX || self.{{SCENE_POSITION_FIELD}}.y != panelY)
            {
                self.{{SCENE_POSITION_FIELD}} = new Vector2(panelX, panelY);
            }
            float headerHeight = 56f;
            float footerHeight = 48f;
            float firstRowY = panelY + headerHeight + 8f;
            float footerY = panelY + panelHeight - footerHeight - 10f;
            float availableRowSpace = footerY - firstRowY - 8f;
            float rowHeight = availableRowSpace / 8f;
            float rowCardHeight = rowHeight - 6f;
            Rect panelRect = new Rect(panelX, panelY, panelWidth, panelHeight);
            Rect headerRect = new Rect(panelX, panelY, panelWidth, headerHeight);
            Rect closeRect = new Rect(panelX + panelWidth - 50f, panelY + 8f, 40f, 40f);
            Rect row1Rect = new Rect(panelX + 16f, firstRowY, panelWidth - 32f, rowCardHeight);
            Rect row2Rect = new Rect(panelX + 16f, firstRowY + rowHeight, panelWidth - 32f, rowCardHeight);
            Rect row3Rect = new Rect(panelX + 16f, firstRowY + rowHeight * 2f, panelWidth - 32f, rowCardHeight);
            Rect row4Rect = new Rect(panelX + 16f, firstRowY + rowHeight * 3f, panelWidth - 32f, rowCardHeight);
            Rect row5Rect = new Rect(panelX + 16f, firstRowY + rowHeight * 4f, panelWidth - 32f, rowCardHeight);
            Rect row6Rect = new Rect(panelX + 16f, firstRowY + rowHeight * 5f, panelWidth - 32f, rowCardHeight);
            Rect row7Rect = new Rect(panelX + 16f, firstRowY + rowHeight * 6f, panelWidth - 32f, rowCardHeight);
            Rect row8Rect = new Rect(panelX + 16f, firstRowY + rowHeight * 7f, panelWidth - 32f, rowCardHeight);
            float tabSpacing = 6f;
            float tabWidth = (panelWidth - 32f - tabSpacing * 3f) / 4f;
            Rect espTab = new Rect(panelX + 16f, footerY, tabWidth, footerHeight);
            Rect aimTab = new Rect(panelX + 16f + (tabWidth + tabSpacing), footerY, tabWidth, footerHeight);
            Rect vipTab = new Rect(panelX + 16f + (tabWidth + tabSpacing) * 2f, footerY, tabWidth, footerHeight);
            Rect settingsTab = new Rect(panelX + 16f + (tabWidth + tabSpacing) * 3f, footerY, tabWidth, footerHeight);

            int rowCount = 0;
            if (menuOpen)
            {
                if (activeTab == 0)
                {
                    rowCount = 7;
                }
                else if (activeTab == 1)
                {
                    if ((state & AimEnabled) != 0)
                    {
                        rowCount = 7;
                    }
                    else if ((state & AimSystemEnabled) != 0)
                    {
                        rowCount = 3;
                    }
                    else
                    {
                        rowCount = 2;
                    }
                }
                else if (activeTab == 2)
                {
                    rowCount = 4;
                }
                else
                {
                    rowCount = 4;
                }
            }

            Vector2 pointer = currentEvent.mousePosition;
            float colorPopupWidth = Mathf.Clamp(panelWidth - 24f, 340f, 460f);
            float colorPopupHeight = 414f;
            float colorPopupX = panelX + (panelWidth - colorPopupWidth) * 0.5f;
            float colorPopupY = panelY + (panelHeight - colorPopupHeight) * 0.5f;

            if (menuOpen && activeModal == ModalFovColor
                && (currentEvent.type == EventType.MouseDown || currentEvent.type == EventType.MouseDrag))
            {
                for (int ch = 0; ch < 3; ch++)
                {
                    float sY = colorPopupY + 110f + (float)ch * 42f;
                    Rect sliderHitRect = new Rect(colorPopupX + 110f, sY, colorPopupWidth - 124f, 38f);
                    Rect sliderTrackRect = new Rect(colorPopupX + 126f, sY + 11f, colorPopupWidth - 146f, 16f);
                    if (sliderHitRect.Contains(pointer))
                    {
                        float pct = Mathf.Clamp01((pointer.x - sliderTrackRect.x) / sliderTrackRect.width);
                        int val = Mathf.Clamp(Mathf.RoundToInt(pct * 255f), 0, 255);
                        if (ch == 0) customR = val;
                        else if (ch == 1) customG = val;
                        else if (ch == 2) customB = val;
                        isRainbow = false;
                        modalState.y = (float)((isBottomTracer ? 2 : 1)
                            | (customR << 3)
                            | (customG << 11)
                            | (1 << 19));
                        modalState.z = (float)((vipMask & 15) | (customB << 4));
                        driverObject.transform.localScale = modalState;
                        currentEvent.Use();
                        break;
                    }
                }
            }

            float fovPopupWidth = Mathf.Clamp(panelWidth - 24f, 340f, 460f);
            float fovPopupHeight = 264f;
            float fovPopupX = panelX + (panelWidth - fovPopupWidth) * 0.5f;
            float fovPopupY = panelY + (panelHeight - fovPopupHeight) * 0.5f;

            if (menuOpen && activeModal == ModalFovSize
                && (currentEvent.type == EventType.MouseDown || currentEvent.type == EventType.MouseDrag))
            {
                Rect fovHit = new Rect(fovPopupX + 40f, fovPopupY + 104f, fovPopupWidth - 80f, 52f);
                Rect fovTrack = new Rect(fovPopupX + 72f, fovPopupY + 120f, fovPopupWidth - 144f, 22f);
                if (fovHit.Contains(pointer))
                {
                    float pct = Mathf.Clamp01((pointer.x - fovTrack.x) / fovTrack.width);
                    fovRadius = Mathf.Clamp(Mathf.Round(40f + pct * 460f), 40f, 500f);
                    driverPos.z = fovRadius;
                    driverObject.transform.position = driverPos;
                    currentEvent.Use();
                }
            }

            Rect toggleBadgeRect = new Rect(16f, 16f, 110f, 34f);
            menuOpen = false;
            self.{{SCENE_MENU_FIELD}} = false;

            bool dragging = (state & StateDragging) != 0;
            bool releasedDrag = false;
            if (menuOpen && currentEvent.type == EventType.MouseDown
                && headerRect.Contains(pointer) && !closeRect.Contains(pointer))
            {
                state |= StateDragging;
                dragging = true;
                currentEvent.Use();
            }
            else if (menuOpen && currentEvent.type == EventType.MouseDrag && dragging)
            {
                Vector2 delta = currentEvent.delta;
                panelX = Mathf.Clamp(panelX + delta.x, 8f, maxPanelX);
                panelY = Mathf.Clamp(panelY + delta.y, 8f, maxPanelY);
                self.{{SCENE_POSITION_FIELD}} = new Vector2(panelX, panelY);
                currentEvent.Use();
            }
            else if (currentEvent.type == EventType.MouseUp && dragging)
            {
                state &= ~StateDragging;
                dragging = false;
                releasedDrag = true;
                currentEvent.Use();
            }

            if (menuOpen && currentEvent.type == EventType.MouseUp
                && !dragging && !releasedDrag)
            {
                if (activeModal != ModalNone)
                {
                    if (activeModal == ModalFovColor)
                    {
                        Rect popupRect = new Rect(colorPopupX, colorPopupY, colorPopupWidth, colorPopupHeight);
                        Rect popupCloseRect = new Rect(colorPopupX + colorPopupWidth - 42f, colorPopupY + 6f, 32f, 32f);
                        Rect applyBtnRect = new Rect(colorPopupX + 14f, colorPopupY + 352f, colorPopupWidth - 28f, 42f);
                        if (popupCloseRect.Contains(pointer) || applyBtnRect.Contains(pointer) || !popupRect.Contains(pointer))
                        {
                            activeModal = ModalNone;
                            modalState.x = 0f;
                            driverObject.transform.localScale = modalState;
                            currentEvent.Use();
                        }
                        else
                        {
                            bool sliderTouched = false;
                            for (int ch = 0; ch < 3; ch++)
                            {
                                float sY = colorPopupY + 110f + (float)ch * 42f;
                                Rect sliderHitRect = new Rect(colorPopupX + 110f, sY, colorPopupWidth - 124f, 38f);
                                Rect sliderTrackRect = new Rect(colorPopupX + 126f, sY + 11f, colorPopupWidth - 146f, 16f);
                                if (sliderHitRect.Contains(pointer))
                                {
                                    float pct = Mathf.Clamp01((pointer.x - sliderTrackRect.x) / sliderTrackRect.width);
                                    int val = Mathf.Clamp(Mathf.RoundToInt(pct * 255f), 0, 255);
                                    if (ch == 0) customR = val;
                                    else if (ch == 1) customG = val;
                                    else if (ch == 2) customB = val;
                                    isRainbow = false;
                                    modalState.y = (float)((isBottomTracer ? 2 : 1)
                                        | (customR << 3)
                                        | (customG << 11)
                                        | (1 << 19));
                                    modalState.z = (float)((vipMask & 15) | (customB << 4));
                                    driverObject.transform.localScale = modalState;
                                    sliderTouched = true;
                                    currentEvent.Use();
                                    break;
                                }
                            }
                            if (!sliderTouched)
                            {
                                float swStartY = colorPopupY + 242f;
                                float swW = (colorPopupWidth - 28f - 4 * 6f) / 5f;
                                float swH = 30f;
                                for (int sw = 0; sw < 10; sw++)
                                {
                                    int swRow = sw / 5;
                                    int swCol = sw % 5;
                                    Rect swRect = new Rect(colorPopupX + 14f + (float)swCol * (swW + 6f), swStartY + 20f + (float)swRow * (swH + 5f), swW, swH);
                                    if (swRect.Contains(pointer))
                                    {
                                        if (sw == 0) { customR = 255; customG = 30; customB = 40; isRainbow = false; }
                                        else if (sw == 1) { customR = 255; customG = 230; customB = 10; isRainbow = false; }
                                        else if (sw == 2) { customR = 20; customG = 255; customB = 80; isRainbow = false; }
                                        else if (sw == 3) { customR = 0; customG = 245; customB = 255; isRainbow = false; }
                                        else if (sw == 4) { customR = 30; customG = 120; customB = 255; isRainbow = false; }
                                        else if (sw == 5) { customR = 175; customG = 30; customB = 255; isRainbow = false; }
                                        else if (sw == 6) { customR = 255; customG = 40; customB = 160; isRainbow = false; }
                                        else if (sw == 7) { customR = 255; customG = 120; customB = 0; isRainbow = false; }
                                        else if (sw == 8) { customR = 255; customG = 255; customB = 255; isRainbow = false; }
                                        else if (sw == 9) { isRainbow = true; }

                                        modalState.y = (float)((isBottomTracer ? 2 : 1)
                                            | (isRainbow ? 4 : 0)
                                            | (customR << 3)
                                            | (customG << 11)
                                            | (1 << 19));
                                        modalState.z = (float)((vipMask & 15) | (customB << 4));
                                        driverObject.transform.localScale = modalState;
                                        currentEvent.Use();
                                        break;
                                    }
                                }
                            }
                        }
                    }
                    else if (activeModal == ModalFovSize)
                    {
                        Rect fovPopupRect = new Rect(fovPopupX, fovPopupY, fovPopupWidth, fovPopupHeight);
                        Rect fovCloseRect = new Rect(fovPopupX + fovPopupWidth - 42f, fovPopupY + 6f, 32f, 32f);
                        Rect fovApplyBtn = new Rect(fovPopupX + 14f, fovPopupY + 208f, fovPopupWidth - 28f, 42f);
                        if (fovCloseRect.Contains(pointer) || fovApplyBtn.Contains(pointer) || !fovPopupRect.Contains(pointer))
                        {
                            activeModal = ModalNone;
                            modalState.x = 0f;
                            driverObject.transform.localScale = modalState;
                            currentEvent.Use();
                        }
                        else
                        {
                            Rect fovHit = new Rect(fovPopupX + 40f, fovPopupY + 104f, fovPopupWidth - 80f, 52f);
                            Rect fovTrack = new Rect(fovPopupX + 72f, fovPopupY + 120f, fovPopupWidth - 144f, 22f);
                            if (fovHit.Contains(pointer))
                            {
                                float pct = Mathf.Clamp01((pointer.x - fovTrack.x) / fovTrack.width);
                                fovRadius = Mathf.Clamp(Mathf.Round(40f + pct * 460f), 40f, 500f);
                                driverPos.z = fovRadius;
                                driverObject.transform.position = driverPos;
                                currentEvent.Use();
                            }
                            else
                            {
                                float btnRowW = fovPopupWidth - 28f;
                                float stepBtnW = 46f;
                                Rect decBtn = new Rect(fovPopupX + 14f, fovPopupY + 160f, stepBtnW, 34f);
                                Rect incBtn = new Rect(fovPopupX + 14f + btnRowW - stepBtnW, fovPopupY + 160f, stepBtnW, 34f);
                                if (decBtn.Contains(pointer))
                                {
                                    fovRadius = Mathf.Clamp(fovRadius - 10f, 40f, 500f);
                                    driverPos.z = fovRadius;
                                    driverObject.transform.position = driverPos;
                                    currentEvent.Use();
                                }
                                else if (incBtn.Contains(pointer))
                                {
                                    fovRadius = Mathf.Clamp(fovRadius + 10f, 40f, 500f);
                                    driverPos.z = fovRadius;
                                    driverObject.transform.position = driverPos;
                                    currentEvent.Use();
                                }
                                else
                                {
                                    float presetW = (btnRowW - stepBtnW * 2f - 24f) / 5f;
                                    for (int p = 0; p < 5; p++)
                                    {
                                        float pVal = p == 0 ? 90f : (p == 1 ? 140f : (p == 2 ? 250f : (p == 3 ? 360f : 500f)));
                                        Rect pRect = new Rect(fovPopupX + 14f + stepBtnW + 4f + (float)p * (presetW + 4f), fovPopupY + 160f, presetW, 34f);
                                        if (pRect.Contains(pointer))
                                        {
                                            fovRadius = pVal;
                                            driverPos.z = fovRadius;
                                            driverObject.transform.position = driverPos;
                                            currentEvent.Use();
                                            break;
                                        }
                                    }
                                }
                            }
                        }
                    }
                    else
                    {
                        float popupWidth = Mathf.Clamp(panelWidth - 24f, 340f, 460f);
                        float popupHeight = activeModal == ModalAimMode ? 220f
                            : (activeModal == ModalHeadRate ? 320f : 166f);
                        float popupX = panelX + (panelWidth - popupWidth) * 0.5f;
                        float popupY = panelY + (panelHeight - popupHeight) * 0.5f;
                        Rect popupRect = new Rect(popupX, popupY, popupWidth, popupHeight);
                        Rect popupCloseRect = new Rect(popupX + popupWidth - 42f, popupY + 6f, 32f, 32f);
                        float optStartY = popupY + 48f;
                        float optRowHeight = 46f;
                        float optSpacing = 6f;

                        if (popupCloseRect.Contains(pointer) || !popupRect.Contains(pointer))
                        {
                            activeModal = ModalNone;
                            modalState.x = 0f;
                            driverObject.transform.localScale = modalState;
                            currentEvent.Use();
                        }
                        else
                        {
                            int optCount = activeModal == ModalAimMode ? 3
                                : (activeModal == ModalHeadRate ? 5 : 2);
                            for (int i = 0; i < optCount; i++)
                            {
                                Rect optRect = new Rect(popupX + 14f, optStartY + (float)i * (optRowHeight + optSpacing), popupWidth - 28f, optRowHeight);
                                if (optRect.Contains(pointer))
                                {
                                    if (activeModal == ModalAimMode)
                                    {
                                        aimMode = i;
                                        state = (state & ~AimModeMask) | (aimMode << AimModeShift);
                                    }
                                    else if (activeModal == ModalHeadRate)
                                    {
                                        headRateIndex = i;
                                        state = (state & ~HeadRateMask) | (headRateIndex << HeadRateShift);
                                    }
                                    else if (activeModal == ModalSystemTarget)
                                    {
                                        if (i == 1) state |= AimSystemHead;
                                        else state &= ~AimSystemHead;
                                    }
                                    else if (activeModal == ModalTracerOrigin)
                                    {
                                        isBottomTracer = (i == 1);
                                        modalState.y = (float)((isBottomTracer ? 2 : 1)
                                            | (isRainbow ? 4 : 0)
                                            | (customR << 3)
                                            | (customG << 11)
                                            | (1 << 19));
                                    }
                                    activeModal = ModalNone;
                                    modalState.x = 0f;
                                    driverObject.transform.localScale = modalState;
                                    currentEvent.Use();
                                    break;
                                }
                            }
                        }
                    }
                }
                else if (closeRect.Contains(pointer))
                {
                    menuOpen = false;
                    activeModal = ModalNone;
                    modalState.x = 0f;
                    driverObject.transform.localScale = modalState;
                }
                else if (espTab.Contains(pointer))
                {
                    activeTab = 0;
                }
                else if (aimTab.Contains(pointer))
                {
                    activeTab = 1;
                }
                else if (vipTab.Contains(pointer))
                {
                    activeTab = 2;
                }
                else if (settingsTab.Contains(pointer))
                {
                    activeTab = 3;
                }
                else
                {
                    int selectedRow = -1;
                    if (row1Rect.Contains(pointer)) selectedRow = 0;
                    else if (row2Rect.Contains(pointer)) selectedRow = 1;
                    else if (row3Rect.Contains(pointer)) selectedRow = 2;
                    else if (row4Rect.Contains(pointer)) selectedRow = 3;
                    else if (row5Rect.Contains(pointer)) selectedRow = 4;
                    else if (row6Rect.Contains(pointer)) selectedRow = 5;
                    else if (row7Rect.Contains(pointer)) selectedRow = 6;
                    else if (row8Rect.Contains(pointer)) selectedRow = 7;

                    if (selectedRow >= 0 && selectedRow < rowCount)
                    {
                        if (activeTab == 0)
                        {
                            if (selectedRow == 6)
                            {
                                activeModal = ModalTracerOrigin;
                                modalState.x = (float)ModalTracerOrigin;
                                driverObject.transform.localScale = modalState;
                            }
                            else
                            {
                                int espBit = selectedRow == 0 ? EspMaster
                                    : (selectedRow == 1 ? EspBox
                                    : (selectedRow == 2 ? EspTracer
                                    : (selectedRow == 3 ? EspHealth
                                    : (selectedRow == 4 ? EspName : EspDistance))));
                                mask ^= espBit;
                            }
                        }
                        else if (activeTab == 1)
                        {
                            int action = 0;
                            if (selectedRow == 0) action = AimActionSilentToggle;
                            else if (selectedRow == 1) action = AimActionSystemToggle;
                            else if ((state & AimEnabled) != 0)
                            {
                                if (selectedRow == 2) action = AimActionSilentTarget;
                                else if (selectedRow == 3) action = AimActionHeadRate;
                                else if (selectedRow == 4) action = AimActionFov;
                                else if (selectedRow == 5) action = AimActionFovSize;
                                else if (selectedRow == 6) action = AimActionFovColor;
                            }
                            else if ((state & AimSystemEnabled) != 0)
                            {
                                if (selectedRow == 2) action = AimActionSystemTarget;
                            }
                            if (action == AimActionSilentToggle)
                            {
                                state ^= AimEnabled;
                                if ((state & AimEnabled) != 0)
                                {
                                    state &= ~AimSystemEnabled;
                                }
                            }
                            else if (action == AimActionSystemToggle)
                            {
                                state ^= AimSystemEnabled;
                                if ((state & AimSystemEnabled) != 0)
                                {
                                    state &= ~AimEnabled;
                                }
                            }
                            else if (action == AimActionSilentTarget)
                            {
                                activeModal = ModalAimMode;
                                modalState.x = (float)ModalAimMode;
                                driverObject.transform.localScale = modalState;
                            }
                            else if (action == AimActionHeadRate)
                            {
                                activeModal = ModalHeadRate;
                                modalState.x = (float)ModalHeadRate;
                                driverObject.transform.localScale = modalState;
                            }
                            else if (action == AimActionFov)
                            {
                                mask ^= EspFov;
                            }
                            else if (action == AimActionFovSize)
                            {
                                activeModal = ModalFovSize;
                                modalState.x = (float)ModalFovSize;
                                driverObject.transform.localScale = modalState;
                            }
                            else if (action == AimActionFovColor)
                            {
                                activeModal = ModalFovColor;
                                modalState.x = (float)ModalFovColor;
                                driverObject.transform.localScale = modalState;
                            }
                            else if (action == AimActionSystemTarget)
                            {
                                activeModal = ModalSystemTarget;
                                modalState.x = (float)ModalSystemTarget;
                                driverObject.transform.localScale = modalState;
                            }
                            else if (action == AimActionNoRecoil)
                            {
                                state ^= NoRecoil;
                            }
                        }
                        else if (activeTab == 2)
                        {
                            if (selectedRow == 1)
                            {
                                state ^= NoRecoil;
                            }
                            else
                            {
                                int vipBit = selectedRow == 0 ? VipFastFire
                                    : (selectedRow == 2 ? VipHeadDamage : VipWideView);
                                vipMask ^= vipBit;
                                modalState.z = (float)((vipMask & 15) | (customB << 4));
                                driverObject.transform.localScale = modalState;
                            }
                        }
                        else if (selectedRow == 0)
                        {
                            auxState ^= AuxFastParachute;
                        }
                        else if (selectedRow == 1)
                        {
                            auxState ^= AuxSpeedRunning;
                        }
                        else if (selectedRow == 2)
                        {
                            mask = EspMask;
                            state &= ~(AimEnabled | AimModeMask | NoRecoil
                                | HeadRateMask | AimSystemEnabled | AimSystemHead);
                            state |= DefaultAimState;
                            aimMode = 2;
                            headRateIndex = 3;
                            auxState &= AuxSpeedRunningApplied;
                            driverPos.z = 140f;
                            driverObject.transform.position = driverPos;
                            fovRadius = 140f;
                            modalState.x = 0f;
                            modalState.y = (float)(1 | (1 << 19) | (0 << 3) | (245 << 11));
                            modalState.z = (float)(255 << 4);
                            driverObject.transform.localScale = modalState;
                            vipMask = 0;
                            isBottomTracer = false;
                            isRainbow = false;
                            customR = 0;
                            customG = 245;
                            customB = 255;
                            activeModal = ModalNone;
                        }
                        else if (selectedRow == 3)
                        {
                            menuOpen = false;
                            activeModal = ModalNone;
                            modalState.x = 0f;
                            driverObject.transform.localScale = modalState;
                        }
                    }
                }
                if (panelRect.Contains(pointer))
                {
                    currentEvent.Use();
                }
            }

            state = (state & ~EspMask) | mask;
            state = (state & ~TabMask) | (activeTab << TabShift);
            self.{{SCENE_MENU_FIELD}} = menuOpen;
            self.{{SCENE_POSITION_FIELD}} = new Vector2(panelX, panelY);
            int packedAux = (lastTapTick << AuxTickShift) | (auxState & AuxMask);
            self.{{SCENE_STATE_FIELD}} = new Vector2(
                (float)state,
                -AuxStateMarker - (float)packedAux);

            try
            {
                Player localPlayer = GameFacade.CurrentLocalPlayer();
                if (localPlayer != null)
                {
                    bool isWide = (vipMask & VipWideView) != 0;
                    bool camWideApplied = driverObject != null && driverObject.transform.localEulerAngles.x > 0.5f;
                    CameraControllerManager camMgr = GameFacade.CurrentCameraControllerManager();
                    Camera cam = Camera.main;
                    if (isWide)
                    {
                        float targetFov = customCamFov >= 50f ? customCamFov : 88f;
                        if (localPlayer.GetSightingState())
                        {
                            if (camMgr != null) camMgr.ReSetFov();
                        }
                        else
                        {
                            if (camMgr != null) camMgr.SetFov(targetFov);
                            if (cam != null) cam.fieldOfView = targetFov;
                            Camera[] allCams = Camera.allCameras;
                            if (allCams != null)
                            {
                                for (int ci = 0; ci < allCams.Length; ci++)
                                {
                                    Camera c = allCams[ci];
                                    if (c != null && !c.name.Contains("UI"))
                                    {
                                        c.fieldOfView = targetFov;
                                    }
                                }
                            }
                        }
                        if (driverObject != null)
                        {
                            driverObject.transform.localEulerAngles = new Vector3(
                                1f,
                                driverObject.transform.localEulerAngles.y,
                                0f);
                        }
                    }
                    else if (camWideApplied)
                    {
                        if (camMgr != null) camMgr.ReSetFov();
                        if (cam != null && cam.fieldOfView > 65f) cam.fieldOfView = 60f;
                        Camera[] allCams = Camera.allCameras;
                        if (allCams != null)
                        {
                            for (int ci = 0; ci < allCams.Length; ci++)
                            {
                                Camera c = allCams[ci];
                                if (c != null && !c.name.Contains("UI") && c.fieldOfView > 65f)
                                {
                                    c.fieldOfView = 60f;
                                }
                            }
                        }
                        if (driverObject != null)
                        {
                            driverObject.transform.localEulerAngles = new Vector3(
                                0f,
                                driverObject.transform.localEulerAngles.y,
                                0f);
                        }
                    }

                    bool isAuth = (state & StateAuthorized) != 0;
                    bool speedRunning = isAuth && (auxState & AuxSpeedRunning) != 0;
                    bool speedRunningApplied = (auxState & AuxSpeedRunningApplied) != 0;
                    PlayerAttributes attributes = localPlayer.Attributes;
                    if (attributes != null)
                    {
                        if (speedRunning)
                        {
                            attributes.SetSpecialRunSpeedScaleByKeyAndValue(
                                PlayerAttributes.{{SPEED_TYPE}}.BuffSystem,
                                SpeedRunningKey, 3f);
                            attributes.BuffWeaponMoveSpeedScale = 2.5f;
                            auxState |= AuxSpeedRunningApplied;
                        }
                        else if (speedRunningApplied)
                        {
                            attributes.RemoveSpecialRunSpeedScaleByKey(
                                PlayerAttributes.{{SPEED_TYPE}}.BuffSystem,
                                SpeedRunningKey);
                            attributes.BuffWeaponMoveSpeedScale = 1.0f;
                            auxState &= ~AuxSpeedRunningApplied;
                        }

                        // Fast Fire (Xáº£ Ä‘áº¡n siÃªu tá»‘c)
                        if ((vipMask & VipFastFire) != 0)
                        {
                            attributes.FireIntervalScale = 0.35f;
                        }
                        else if (attributes.FireIntervalScale < 0.9f)
                        {
                            attributes.FireIntervalScale = 1.0f;
                        }

                        // Buff Damage (TÄƒng sÃ¡t thÆ°Æ¡ng Ä‘áº§u, thÃ¢n, vÅ© khÃ­ cá»±c Ä‘áº¡i)
                        if ((vipMask & VipHeadDamage) != 0)
                        {
                            attributes.HeadDamageIncreaseScale = 10000.0f;
                            attributes.BuffWeaponDamageScale = 10000.0f;
                            attributes.DamageAdditionScale = 10000.0f;
                            attributes.ExecuteDamageScale = 10000.0f;
                        }
                        else if (attributes.HeadDamageIncreaseScale > 10.0f)
                        {
                            attributes.HeadDamageIncreaseScale = 0f;
                            attributes.BuffWeaponDamageScale = 0f;
                            attributes.DamageAdditionScale = 0f;
                            attributes.ExecuteDamageScale = 0f;
                        }

                        // Äáº¡n tháº³ng / No Recoil
                        if ((state & NoRecoil) != 0)
                        {
                            attributes.SkillScatterRate = -1f;
                            attributes.SkillScatterRateSighting = -1f;
                        }
                        else if (attributes.SkillScatterRate < -0.5f)
                        {
                            attributes.SkillScatterRate = 0f;
                            attributes.SkillScatterRateSighting = 0f;
                        }
                    }

                    if ((auxState & AuxFastParachute) != 0)
                    {
                        bool skySurfing = localPlayer.IsSkySurfing;
                        bool skyDiving = localPlayer.IsSkyDiving;
                        bool parachuting = localPlayer.IsParachuting;
                        if (skySurfing)
                        {
                            localPlayer.RequestSkyDiving();
                        }
                        else if (skyDiving || parachuting)
                        {
                            CharacterController controller = localPlayer.CharacterController;
                            if (controller != null && controller.enabled)
                            {
                                RaycastHit groundHit;
                                Vector3 origin = controller.transform.position;
                                bool foundGround = Physics.Raycast(
                                    origin,
                                    new Vector3(0f, -1f, 0f),
                                    out groundHit,
                                    2048f,
                                    -5,
                                    QueryTriggerInteraction.Ignore);
                                if (foundGround)
                                {
                                    bool landed = controller.isGrounded;
                                    float groundDistance = groundHit.distance;
                                    if (!landed && groundDistance > 0f)
                                    {
                                        float contactPadding = controller.skinWidth;
                                        if (contactPadding < 0.05f) contactPadding = 0.05f;
                                        float moveDistance = groundDistance + contactPadding;
                                        float frameStep = Time.deltaTime * 768f;
                                        if (frameStep < 0.5f) frameStep = 0.5f;
                                        else if (frameStep > 32f) frameStep = 32f;
                                        if (moveDistance > frameStep) moveDistance = frameStep;
                                        CollisionFlags collision = controller.Move(new Vector3(0f, -moveDistance, 0f));
                                        landed = (collision & CollisionFlags.Below) != 0 || controller.isGrounded;
                                    }
                                    if (landed)
                                    {
                                        localPlayer.StopParachuting(true);
                                        localPlayer.OnLandFinsish();
                                    }
                                }
                            }
                        }
                    }

                    packedAux = (lastTapTick << AuxTickShift) | (auxState & AuxMask);
                    self.{{SCENE_STATE_FIELD}} = new Vector2(
                        (float)state,
                        -AuxStateMarker - (float)packedAux);
                }
            }
            catch (Exception)
            {
            }

            if (currentEvent.type != EventType.Repaint)
            {
                return;
            }

            Matrix4x4 savedMatrix = GUI.matrix;
            Color savedColor = GUI.color;
            try
            {
                GUI.matrix = Matrix4x4.identity;
                Texture2D pixel = Texture2D.whiteTexture;
                if (pixel != null
                    && screenWidth > 0 && screenHeight > 0)
                {
                    Camera camera = Camera.main;
                    Player localPlayer = GameFacade.CurrentLocalPlayer();
                    Transform localRoot = localPlayer == null ? null : localPlayer.RootTransform;

                    if ((state & StateAuthorized) != 0 && (state & AimEnabled) != 0 && (mask & EspFov) != 0)
                    {
                        Color fovBaseColor = isRainbow
                            ? Color.white
                            : new Color((float)customR / 255f, (float)customG / 255f, (float)customB / 255f, 0.92f);
                        if (!isRainbow)
                        {
                            GUI.color = fovBaseColor;
                        }
                        float circleX = (float)screenWidth * 0.5f;
                        float circleY = (float)screenHeight * 0.5f;
                        float rainbowPhase = Time.unscaledTime * 2.5f;
                        for (int segment = 0; segment < 64; segment++)
                        {
                            if (isRainbow)
                            {
                                float fovHue = (rainbowPhase + (float)segment / 64f) % 1f;
                                if (fovHue < 0f) fovHue += 1f;
                                float fr = Mathf.Clamp01(Mathf.Abs(fovHue * 6f - 3f) - 1f);
                                float fg = Mathf.Clamp01(2f - Mathf.Abs(fovHue * 6f - 2f));
                                float fb = Mathf.Clamp01(2f - Mathf.Abs(fovHue * 6f - 4f));
                                GUI.color = new Color(fr, fg, fb, 0.92f);
                            }
                            float drawFov = fovRadius;
                            float angle0 = (float)segment * 0.09817477f;
                            float angle1 = (float)(segment + 1) * 0.09817477f;
                            float x0 = circleX + Mathf.Cos(angle0) * drawFov;
                            float y0 = circleY + Mathf.Sin(angle0) * drawFov;
                            float x1 = circleX + Mathf.Cos(angle1) * drawFov;
                            float y1 = circleY + Mathf.Sin(angle1) * drawFov;
                            float dx = x1 - x0;
                            float dy = y1 - y0;
                            float length = Mathf.Sqrt(dx * dx + dy * dy);
                            float angle = Mathf.Atan2(dy, dx) * 57.29578f;
                            GUI.matrix = Matrix4x4.TRS(
                                new Vector3(x0, y0, 0f),
                                Quaternion.Euler(0f, 0f, angle),
                                Vector3.one);
                            GUI.DrawTexture(new Rect(0f, -0.75f, length, 1.5f), pixel);
                        }
                        GUI.matrix = Matrix4x4.identity;
                    }

                    if ((state & StateAuthorized) != 0 && ((mask & EspMaster) != 0 || (state & AimSystemEnabled) != 0))
                    {
                        {{MATCH_TYPE}} match = GameFacade.CurrentMatch();
                        IList players = match == null ? null : match.{{MATCH_PLAYERS_METHOD}}();
                        GameObject localObject = localPlayer == null
                            ? null : localPlayer.gameObject;
                        if (camera != null && localPlayer != null
                            && localObject != null && localObject.activeInHierarchy
                            && localRoot != null && players != null)
                        {
                            Vector3 bestAimTargetPos = Vector3.zero;
                            float bestAimDistSq = 999999999f;

                            for (int index = 0; index < players.Count; index++)
                            {
                                try
                                {
                                Player player = players[index] as Player;
                                if (player == null)
                                {
                                    continue;
                                }
                                GameObject playerObject = player.gameObject;
                                if (playerObject == null || !playerObject.activeInHierarchy)
                                {
                                    continue;
                                }
                                Transform root = player.RootTransform;
                                if (player.IsLocalPlayer()
                                    || player.IsLocalTeammate(false) || !player.IsVisible())
                                {
                                    continue;
                                }

                                bool dying = player.IsDieing;
                                int health = player.CurHP;
                                int maximumHealth = player.MaxHP;
                                if (health <= 0 && !dying)
                                {
                                    continue;
                                }
                                Transform head = player.GetHeadTF();
                                if (root == null || head == null)
                                {
                                    continue;
                                }

                                float distance = Vector3.Distance(localRoot.position, root.position);
                                if (distance > 500f)
                                {
                                    continue;
                                }

                                if ((state & AimSystemEnabled) != 0)
                                {
                                    Vector3 aimTargetPoint = ((state & AimSystemHead) != 0)
                                        ? head.position
                                        : (head.position - new Vector3(0f, 0.22f, 0f));
                                    Vector3 screenAim = camera.WorldToScreenPoint(aimTargetPoint);
                                    if (screenAim.z > 0.5f
                                        && !float.IsNaN(screenAim.x) && !float.IsNaN(screenAim.y)
                                        && !float.IsInfinity(screenAim.x) && !float.IsInfinity(screenAim.y))
                                    {
                                        float adx = screenAim.x - (float)screenWidth * 0.5f;
                                        float ady = screenAim.y - (float)screenHeight * 0.5f;
                                        float adistSq = adx * adx + ady * ady;
                                        if (adistSq < bestAimDistSq)
                                        {
                                            bestAimDistSq = adistSq;
                                            bestAimTargetPos = aimTargetPoint;
                                        }
                                    }
                                }

                                if ((mask & EspMaster) == 0)
                                {
                                    continue;
                                }
                                Vector3 feetScreen = camera.WorldToScreenPoint(root.position);
                                Vector3 headScreen = camera.WorldToScreenPoint(head.position);
                                if (feetScreen.z <= 0f || headScreen.z <= 0f)
                                {
                                    continue;
                                }
                                if (float.IsNaN(feetScreen.x) || float.IsNaN(feetScreen.y)
                                    || float.IsNaN(feetScreen.z) || float.IsNaN(headScreen.x)
                                    || float.IsNaN(headScreen.y) || float.IsNaN(headScreen.z)
                                    || float.IsInfinity(feetScreen.x) || float.IsInfinity(feetScreen.y)
                                    || float.IsInfinity(headScreen.x) || float.IsInfinity(headScreen.y))
                                {
                                    continue;
                                }

                                float height = Mathf.Abs(headScreen.y - feetScreen.y) * 1.0909091f;
                                if (height < 2f)
                                {
                                    continue;
                                }
                                float width = height * 0.5f;
                                float left = headScreen.x - width * 0.5f;
                                float top = (float)screenHeight - headScreen.y;
                                float thickness = 1.5f;
                                if (float.IsNaN(left) || float.IsNaN(top)
                                    || float.IsInfinity(left) || float.IsInfinity(top)
                                    || left > (float)screenWidth || left + width < 0f
                                    || top > (float)screenHeight || top + height < 0f)
                                {
                                    continue;
                                }
                                Color espColor = new Color((float)customR / 255f, (float)customG / 255f, (float)customB / 255f, 0.95f);

                                float rainbowTime = Time.unscaledTime * 1.5f;
                                if ((mask & EspBox) != 0)
                                {
                                    if (isRainbow)
                                    {
                                        float boxPhase = rainbowTime + (left * 0.002f);
                                        int hSteps = 12;
                                        int vSteps = 16;
                                        float stepW = width / (float)hSteps;
                                        float stepH = height / (float)vSteps;

                                        // Cáº¡nh trÃªn (u: 0.00 -> 0.25)
                                        for (int i = 0; i < hSteps; i++)
                                        {
                                            float u = 0.25f * ((float)i / (float)hSteps);
                                            float segHue = (boxPhase + u) % 1f;
                                            if (segHue < 0f) segHue += 1f;
                                            float r = Mathf.Clamp01(Mathf.Abs(segHue * 6f - 3f) - 1f);
                                            float g = Mathf.Clamp01(2f - Mathf.Abs(segHue * 6f - 2f));
                                            float b = Mathf.Clamp01(2f - Mathf.Abs(segHue * 6f - 4f));
                                            float trail = ((rainbowTime * 2f - u * 2f) % 1f + 1f) % 1f;
                                            float a = 0.45f + 0.55f * (1f - trail);
                                            GUI.color = new Color(r, g, b, a);
                                            GUI.DrawTexture(new Rect(left + (float)i * stepW, top, stepW + 0.5f, thickness), pixel);
                                        }

                                        // Cáº¡nh pháº£i (u: 0.25 -> 0.50)
                                        for (int i = 0; i < vSteps; i++)
                                        {
                                            float u = 0.25f + 0.25f * ((float)i / (float)vSteps);
                                            float segHue = (boxPhase + u) % 1f;
                                            if (segHue < 0f) segHue += 1f;
                                            float r = Mathf.Clamp01(Mathf.Abs(segHue * 6f - 3f) - 1f);
                                            float g = Mathf.Clamp01(2f - Mathf.Abs(segHue * 6f - 2f));
                                            float b = Mathf.Clamp01(2f - Mathf.Abs(segHue * 6f - 4f));
                                            float trail = ((rainbowTime * 2f - u * 2f) % 1f + 1f) % 1f;
                                            float a = 0.45f + 0.55f * (1f - trail);
                                            GUI.color = new Color(r, g, b, a);
                                            GUI.DrawTexture(new Rect(left + width - thickness, top + (float)i * stepH, thickness, stepH + 0.5f), pixel);
                                        }

                                        // Cáº¡nh dÆ°á»›i (u: 0.50 -> 0.75)
                                        for (int i = 0; i < hSteps; i++)
                                        {
                                            float u = 0.50f + 0.25f * ((float)i / (float)hSteps);
                                            float segHue = (boxPhase + u) % 1f;
                                            if (segHue < 0f) segHue += 1f;
                                            float r = Mathf.Clamp01(Mathf.Abs(segHue * 6f - 3f) - 1f);
                                            float g = Mathf.Clamp01(2f - Mathf.Abs(segHue * 6f - 2f));
                                            float b = Mathf.Clamp01(2f - Mathf.Abs(segHue * 6f - 4f));
                                            float trail = ((rainbowTime * 2f - u * 2f) % 1f + 1f) % 1f;
                                            float a = 0.45f + 0.55f * (1f - trail);
                                            GUI.color = new Color(r, g, b, a);
                                            GUI.DrawTexture(new Rect(left + width - (float)(i + 1) * stepW, top + height - thickness, stepW + 0.5f, thickness), pixel);
                                        }

                                        // Cáº¡nh trÃ¡i (u: 0.75 -> 1.00)
                                        for (int i = 0; i < vSteps; i++)
                                        {
                                            float u = 0.75f + 0.25f * ((float)i / (float)vSteps);
                                            float segHue = (boxPhase + u) % 1f;
                                            if (segHue < 0f) segHue += 1f;
                                            float r = Mathf.Clamp01(Mathf.Abs(segHue * 6f - 3f) - 1f);
                                            float g = Mathf.Clamp01(2f - Mathf.Abs(segHue * 6f - 2f));
                                            float b = Mathf.Clamp01(2f - Mathf.Abs(segHue * 6f - 4f));
                                            float trail = ((rainbowTime * 2f - u * 2f) % 1f + 1f) % 1f;
                                            float a = 0.45f + 0.55f * (1f - trail);
                                            GUI.color = new Color(r, g, b, a);
                                            GUI.DrawTexture(new Rect(left, top + height - (float)(i + 1) * stepH, thickness, stepH + 0.5f), pixel);
                                        }
                                    }
                                    else
                                    {
                                        GUI.color = espColor;
                                        GUI.DrawTexture(new Rect(left, top, width, thickness), pixel);
                                        GUI.DrawTexture(new Rect(left, top + height - thickness, width, thickness), pixel);
                                        GUI.DrawTexture(new Rect(left, top, thickness, height), pixel);
                                        GUI.DrawTexture(new Rect(left + width - thickness, top, thickness, height), pixel);
                                    }
                                }

                                if ((mask & EspTracer) != 0)
                                {
                                    float startX = (float)screenWidth * 0.5f;
                                    float startY = isBottomTracer ? ((float)screenHeight - 20f) : 80f;
                                    float endX = left + width * 0.5f;
                                    float endY = isBottomTracer ? (top + height) : (top + height / 35f);
                                    float tracerX = endX - startX;
                                    float tracerY = endY - startY;
                                    float tracerLength = Mathf.Sqrt(
                                        tracerX * tracerX + tracerY * tracerY);
                                    float tracerAngle = Mathf.Atan2(
                                        tracerY, tracerX) * 57.29578f;
                                    GUI.matrix = Matrix4x4.TRS(
                                        new Vector3(startX, startY, 0f),
                                        Quaternion.Euler(0f, 0f, tracerAngle),
                                        Vector3.one);

                                    if (isRainbow)
                                    {
                                        int lineSteps = 28;
                                        float segLen = tracerLength / (float)lineSteps;
                                        float tracerPhase = rainbowTime * 1.5f + (left * 0.002f);
                                        for (int s = 0; s < lineSteps; s++)
                                        {
                                            float normT = (float)s / (float)lineSteps;
                                            float lineHue = (tracerPhase - normT * 1.2f) % 1f;
                                            if (lineHue < 0f) lineHue += 1f;
                                            float lr = Mathf.Clamp01(Mathf.Abs(lineHue * 6f - 3f) - 1f);
                                            float lg = Mathf.Clamp01(2f - Mathf.Abs(lineHue * 6f - 2f));
                                            float lb = Mathf.Clamp01(2f - Mathf.Abs(lineHue * 6f - 4f));

                                            float baseAlpha = 0.20f + 0.80f * (normT * normT);
                                            float wave = ((tracerPhase * 2f - normT * 2.5f) % 1f + 1f) % 1f;
                                            float waveAlpha = 0.6f + 0.4f * (1f - wave);
                                            float la = Mathf.Clamp01(baseAlpha * waveAlpha);

                                            float segThick = thickness * (0.75f + 0.45f * normT);

                                            GUI.color = new Color(lr, lg, lb, la);
                                            GUI.DrawTexture(new Rect(
                                                (float)s * segLen, -segThick * 0.5f,
                                                segLen + 0.5f, segThick), pixel);
                                        }
                                    }
                                    else
                                    {
                                        GUI.color = espColor;
                                        GUI.DrawTexture(new Rect(0f, -thickness * 0.5f, tracerLength, thickness), pixel);
                                    }
                                    GUI.matrix = Matrix4x4.identity;
                                }

                                if ((mask & EspHealth) != 0)
                                {
                                    float healthRatio = maximumHealth > 0
                                        ? Mathf.Clamp01((float)health / (float)maximumHealth)
                                        : 0f;
                                    float healthX = left + width + 2f;
                                    GUI.color = new Color(0f, 0f, 0f, 0.9f);
                                    GUI.DrawTexture(new Rect(healthX, top, 5f, height), pixel);
                                    GUI.color = dying || healthRatio < 0.3f
                                        ? new Color(1f, 0f, 0f, 1f)
                                        : (healthRatio <= 0.6f
                                            ? new Color(1f, 1f, 0f, 1f)
                                            : new Color(0f, 1f, 0f, 1f));
                                    GUI.DrawTexture(new Rect(
                                        healthX + 1f,
                                        top + height - height * healthRatio,
                                        3f,
                                        height * healthRatio), pixel);
                                }

                                float labelScale = 0.72f;
                                if ((mask & EspName) != 0)
                                {
                                    string nickname = player.NickName;
                                    if (nickname == null) nickname = "?";
                                    GUI.color = dying
                                        ? new Color(1f, 0f, 0f, 1f)
                                        : new Color(1f, 1f, 0f, 1f);
                                    float nicknameWidth = Mathf.Clamp(
                                        (float)nickname.Length * 6.2f, width, 220f);
                                    GUI.matrix = Matrix4x4.TRS(
                                        new Vector3(
                                            left + width * 0.5f - nicknameWidth * 0.5f,
                                            top - 14f,
                                            0f),
                                        Quaternion.identity,
                                        new Vector3(labelScale, labelScale, 1f));
                                    GUI.Label(new Rect(
                                        0f, 0f,
                                        nicknameWidth / labelScale,
                                        18f / labelScale), nickname);
                                    GUI.matrix = Matrix4x4.identity;
                                }

                                if ((mask & EspDistance) != 0)
                                {
                                    int distanceValue = (int)distance;
                                    if (distanceValue < 0) distanceValue = 0;
                                    if (distanceValue > 999) distanceValue = 999;
                                    int digitCount = distanceValue >= 100 ? 3
                                        : (distanceValue >= 10 ? 2 : 1);
                                    float glyphWidth = 6f;
                                    float glyphHeight = 10f;
                                    float glyphThickness = 1.5f;
                                    float glyphAdvance = 8f;
                                    float meterWidth = 7f;
                                    float distanceWidth = digitCount * glyphAdvance
                                        + meterWidth + 2f;
                                    float distanceX = left + width * 0.5f
                                        - distanceWidth * 0.5f;
                                    float distanceY = top + height + 5f;
                                    GUI.color = Color.white;
                                    int divisor = digitCount == 3 ? 100
                                        : (digitCount == 2 ? 10 : 1);
                                    for (int digitIndex = 0; digitIndex < digitCount; digitIndex++)
                                    {
                                        int digit = (distanceValue / divisor) % 10;
                                        int segments = digit == 0 ? 63
                                            : (digit == 1 ? 6
                                            : (digit == 2 ? 91
                                            : (digit == 3 ? 79
                                            : (digit == 4 ? 102
                                            : (digit == 5 ? 109
                                            : (digit == 6 ? 125
                                            : (digit == 7 ? 7
                                            : (digit == 8 ? 127 : 111))))))));
                                        float glyphX = distanceX + digitIndex * glyphAdvance;
                                        float middleY = distanceY + glyphHeight * 0.5f
                                            - glyphThickness * 0.5f;
                                        if ((segments & 1) != 0)
                                            GUI.DrawTexture(new Rect(
                                                glyphX, distanceY, glyphWidth, glyphThickness), pixel);
                                        if ((segments & 2) != 0)
                                            GUI.DrawTexture(new Rect(
                                                glyphX + glyphWidth - glyphThickness,
                                                distanceY, glyphThickness, glyphHeight * 0.5f), pixel);
                                        if ((segments & 4) != 0)
                                            GUI.DrawTexture(new Rect(
                                                glyphX + glyphWidth - glyphThickness,
                                                middleY, glyphThickness, glyphHeight * 0.5f), pixel);
                                        if ((segments & 8) != 0)
                                            GUI.DrawTexture(new Rect(
                                                glyphX, distanceY + glyphHeight - glyphThickness,
                                                glyphWidth, glyphThickness), pixel);
                                        if ((segments & 16) != 0)
                                            GUI.DrawTexture(new Rect(
                                                glyphX, middleY, glyphThickness, glyphHeight * 0.5f), pixel);
                                        if ((segments & 32) != 0)
                                            GUI.DrawTexture(new Rect(
                                                glyphX, distanceY, glyphThickness, glyphHeight * 0.5f), pixel);
                                        if ((segments & 64) != 0)
                                            GUI.DrawTexture(new Rect(
                                                glyphX, middleY, glyphWidth, glyphThickness), pixel);
                                        divisor /= 10;
                                    }
                                    float meterX = distanceX + digitCount * glyphAdvance + 1f;
                                    float meterY = distanceY + 2f;
                                    GUI.DrawTexture(new Rect(
                                        meterX, meterY, glyphThickness, glyphHeight - 2f), pixel);
                                    GUI.DrawTexture(new Rect(
                                        meterX + 3f, meterY, glyphThickness, glyphHeight - 2f), pixel);
                                    GUI.DrawTexture(new Rect(
                                        meterX + glyphThickness, meterY,
                                        2f, glyphThickness), pixel);
                                    GUI.DrawTexture(new Rect(
                                        meterX + glyphThickness, meterY + 4f,
                                        2f, glyphThickness), pixel);
                                    GUI.matrix = Matrix4x4.identity;
                                }
                                }
                                catch (Exception)
                                {
                                    // A recycled entity is skipped without aborting the frame.
                                }
                            }

                            if ((state & AimSystemEnabled) != 0 && bestAimTargetPos != Vector3.zero && camera != null)
                            {
                                Vector3 aimDirection = bestAimTargetPos - camera.transform.position;
                                if (aimDirection.sqrMagnitude > 0.01f)
                                {
                                    Quaternion targetAimRot = Quaternion.LookRotation(aimDirection);
                                    camera.transform.rotation = Quaternion.Slerp(camera.transform.rotation, targetAimRot, 20f * Time.deltaTime);
                                }
                            }
                        }
                    }

                    if (menuOpen)
                    {
                        GUI.matrix = Matrix4x4.identity;

                        // 1. ThÃ¢n menu: Obsidian Cyber Dark (Chassis cÃ´ng nghá»‡ tÆ°Æ¡ng lai)
                        GUI.color = new Color(0.035f, 0.040f, 0.058f, 0.97f);
                        GUI.DrawTexture(panelRect, pixel);

                        // 2. Viá»n phÃ¡t sÃ¡ng Neon Cam Chakra Cá»­u VÄ© (Kurama Flame 2px)
                        GUI.color = new Color(1.0f, 0.46f, 0.05f, 0.95f);
                        GUI.DrawTexture(new Rect(panelX, panelY, panelWidth, 2f), pixel);
                        GUI.DrawTexture(new Rect(panelX, panelY + panelHeight - 2f, panelWidth, 2f), pixel);
                        GUI.DrawTexture(new Rect(panelX, panelY, 2f, panelHeight), pixel);
                        GUI.DrawTexture(new Rect(panelX + panelWidth - 2f, panelY, 2f, panelHeight), pixel);

                        // 3. Viá»n Ã¡nh sÃ¡ng phá»¥ Cyber Cyan Rasengan (1px bÃªn trong)
                        GUI.color = new Color(0.0f, 0.92f, 1.0f, 0.45f);
                        GUI.DrawTexture(new Rect(panelX + 2f, panelY + 2f, panelWidth - 4f, 1f), pixel);
                        GUI.DrawTexture(new Rect(panelX + 2f, panelY + panelHeight - 3f, panelWidth - 4f, 1f), pixel);

                        // 4. GÃ³c vÃ¡t cÃ´ng nghá»‡ (Corner Tech HUD Brackets - 4 gÃ³c nháº«n giáº£ Cyberpunk)
                        GUI.color = new Color(0.0f, 0.95f, 1.0f, 1f);
                        GUI.DrawTexture(new Rect(panelX - 1f, panelY - 1f, 16f, 3f), pixel);
                        GUI.DrawTexture(new Rect(panelX - 1f, panelY - 1f, 3f, 16f), pixel);
                        GUI.DrawTexture(new Rect(panelX + panelWidth - 15f, panelY - 1f, 16f, 3f), pixel);
                        GUI.DrawTexture(new Rect(panelX + panelWidth - 2f, panelY - 1f, 3f, 16f), pixel);
                        GUI.DrawTexture(new Rect(panelX - 1f, panelY + panelHeight - 2f, 16f, 3f), pixel);
                        GUI.DrawTexture(new Rect(panelX - 1f, panelY + panelHeight - 15f, 3f, 16f), pixel);
                        GUI.DrawTexture(new Rect(panelX + panelWidth - 15f, panelY + panelHeight - 2f, 16f, 3f), pixel);
                        GUI.DrawTexture(new Rect(panelX + panelWidth - 2f, panelY + panelHeight - 15f, 3f, 16f), pixel);

                        // 5. Thanh tiÃªu Ä‘á» Header
                        GUI.color = new Color(0.075f, 0.085f, 0.125f, 1f);
                        GUI.DrawTexture(headerRect, pixel);

                        // ÄÆ°á»ng dáº£i phÃ¡t sÃ¡ng ngÄƒn cÃ¡ch Header vÃ  Body
                        GUI.color = new Color(0.0f, 0.95f, 1.0f, 1f);
                        GUI.DrawTexture(new Rect(panelX, panelY + headerHeight - 1f, panelWidth, 2f), pixel);
                        GUI.color = new Color(1.0f, 0.82f, 0.2f, 0.5f);
                        GUI.DrawTexture(new Rect(panelX, panelY + headerHeight + 1f, panelWidth, 1f), pixel);

                        // TiÃªu Ä‘á» PROXY VIP VN V5
                        GUI.color = new Color(0.0f, 0.95f, 1.0f, 1f);
                        float titleWidth = Mathf.Clamp(panelWidth - 40f, 240f, 420f);
                        GUI.Label(new Rect(
                            panelX + panelWidth * 0.5f - titleWidth * 0.5f,
                            panelY + 8f, titleWidth, 22f), "â˜…  PROXY VIP VN V5  â˜…");

                        GUI.color = new Color(1.0f, 0.82f, 0.2f, 0.95f);
                        float subTitleWidth = Mathf.Clamp(panelWidth - 60f, 220f, 380f);
                        GUI.Label(new Rect(
                            panelX + panelWidth * 0.5f - subTitleWidth * 0.5f,
                            panelY + 30f, subTitleWidth, 18f), "â— MOD MENU FREE FIRE OB55 â—");

                        // NÃºt Ä‘Ã³ng menu mÃ u Ä‘á» VIP
                        GUI.color = new Color(0.85f, 0.12f, 0.18f, 1f);
                        GUI.DrawTexture(closeRect, pixel);
                        GUI.color = new Color(1.0f, 0.40f, 0.50f, 0.7f);
                        GUI.DrawTexture(new Rect(closeRect.x, closeRect.y, closeRect.width, 1.5f), pixel);
                        GUI.color = Color.white;
                        GUI.Label(new Rect(
                            closeRect.x + closeRect.width * 0.5f - 7f,
                            closeRect.y + closeRect.height * 0.5f - 10f, 20f, 20f), "âœ•");

                        for (int row = 0; row < rowCount; row++)
                        {
                            Rect rowRect = row == 0 ? row1Rect
                                : (row == 1 ? row2Rect
                                : (row == 2 ? row3Rect
                                : (row == 3 ? row4Rect
                                : (row == 4 ? row5Rect
                                : (row == 5 ? row6Rect
                                : (row == 6 ? row7Rect : row8Rect))))));
                            int rowBit = 0;
                            string rowLabel = null;
                            if (activeTab == 0)
                            {
                                if (row == 6)
                                {
                                    rowBit = 0;
                                    string originStr = isBottomTracer ? "ÄÃY MÃ€N HÃŒNH" : "Äá»ˆNH MÃ€N HÃŒNH";
                                    rowLabel = "ðŸ“ Gá»‘c DÃ¢y ESP: " + originStr + "  [Chá»n]";
                                }
                                else
                                {
                                    rowBit = row == 0 ? EspMaster
                                        : (row == 1 ? EspBox
                                        : (row == 2 ? EspTracer
                                        : (row == 3 ? EspHealth
                                        : (row == 4 ? EspName : EspDistance))));
                                    rowLabel = row == 0 ? "â—ˆ Báº­t ESP Tá»•ng (Hiá»‡n Äá»‹ch)"
                                        : (row == 1 ? "â–£ ESP Khung (Há»™p 2D)"
                                        : (row == 2 ? "âŒ ESP DÃ¢y (DÃ¢y Ná»‘i TÃ¢m)"
                                        : (row == 3 ? "â™¥ ESP MÃ¡u (Thanh MÃ¡u)"
                                        : (row == 4 ? "ðŸ‘¤ ESP TÃªn NgÆ°á»i ChÆ¡i" : "â—Ž ESP Khoáº£ng CÃ¡ch (MÃ©t)"))));
                                }
                            }
                            else if (activeTab == 1)
                            {
                                if (row == 0)
                                {
                                    rowBit = AimEnabled;
                                    rowLabel = "âš¡ Silent Aim (Äáº¡n Äuá»•i / Báº» HÆ°á»›ng)";
                                }
                                else if (row == 1)
                                {
                                    rowBit = AimSystemEnabled;
                                    rowLabel = "ðŸŽ¯ Tá»± Äá»™ng KÃ©o TÃ¢m (Auto Aim)";
                                }
                                else if ((state & AimEnabled) != 0)
                                {
                                    if (row == 2)
                                    {
                                        string modeStr = aimMode == 0 ? "NGá»°C / THÃ‚N"
                                            : (aimMode == 1 ? "Äáº¦U (Headshot)" : "ÄA ÄIá»‚M (Random)");
                                        rowLabel = "ðŸŽ¯ Vá»‹ TrÃ­ GÄƒm TÃ¢m: " + modeStr + "  [Chá»n]";
                                    }
                                    else if (row == 3)
                                    {
                                        string rateStr = headRateIndex == 0 ? "0%"
                                            : (headRateIndex == 1 ? "25%"
                                            : (headRateIndex == 2 ? "50%"
                                            : (headRateIndex == 3 ? "75%" : "100% (Full Äá»)")));
                                        rowLabel = "âš¡ Tá»· Lá»‡ TrÃºng Äáº§u: " + rateStr + "  [Chá»n]";
                                    }
                                    else if (row == 4)
                                    {
                                        rowBit = EspFov;
                                        rowLabel = "ðŸŒ€ VÃ²ng TrÃ²n Ngáº¯m (VÃ²ng FOV)";
                                    }
                                    else if (row == 5)
                                    {
                                        string fovDesc = fovRadius < 85f ? "SiÃªu KÃ­n"
                                            : (fovRadius < 125f ? "KÃ­n ÄÃ¡o"
                                            : (fovRadius < 170f ? "Chuáº©n"
                                            : (fovRadius < 250f ? "Rá»™ng" : "Cá»±c Äáº¡i")));
                                        rowLabel = "ðŸ“ Cá»¡ VÃ²ng FOV: " + Mathf.RoundToInt(fovRadius) + "px (" + fovDesc + ")  [KÃ©o TrÆ°á»£t]";
                                    }
                                    else if (row == 6)
                                    {
                                        string colorStr = isRainbow
                                            ? "ðŸŒˆ Cáº§u Vá»“ng RGB (7 MÃ u Äá»™ng)"
                                            : ("#" + customR.ToString("X2") + customG.ToString("X2") + customB.ToString("X2")
                                                + " [R:" + customR + " G:" + customG + " B:" + customB + "]");
                                        rowLabel = "ðŸŽ¨ Báº£ng MÃ u FOV: " + colorStr + "  [Äá»•i MÃ u]";
                                    }
                                }
                                else if ((state & AimSystemEnabled) != 0)
                                {
                                    if (row == 2)
                                    {
                                        string targetStr = (state & AimSystemHead) != 0 ? "Äáº¦U (Headshot)" : "Cá»” (Tá»± NhiÃªn)";
                                        rowLabel = "ðŸŽ¯ Vá»‹ TrÃ­ KÃ©o TÃ¢m: " + targetStr + "  [Chá»n]";
                                    }
                                }
                            }
                            else if (activeTab == 2)
                            {
                                if (row == 0)
                                {
                                    rowBit = VipFastFire;
                                    rowLabel = "âš¡ Xáº£ Äáº¡n SiÃªu Tá»‘c (Fast Fire Rate)";
                                }
                                else if (row == 1)
                                {
                                    rowBit = NoRecoil;
                                    rowLabel = "ðŸ”¥ Äáº¡n Tháº³ng 100% (No Recoil / lá»—i dame cao)";
                                }
                                else if (row == 2)
                                {
                                    rowBit = VipHeadDamage;
                                    rowLabel = "ðŸ’¥ TÄƒng SÃ¡t ThÆ°Æ¡ng + MÃ¡u áº¢o 999999 (Fake Dmg)";
                                }
                                else if (row == 3)
                                {
                                    rowBit = VipWideView;
                                    rowLabel = "ðŸ“± GÃ³c NhÃ¬n Rá»™ng iPad / Cam Xa (FOV 88Â°)";
                                }
                            }
                            else
                            {
                                if (row == 0)
                                {
                                    rowBit = -AuxFastParachute;
                                    rowLabel = "ðŸŒª Nháº£y DÃ¹ SiÃªu Tá»‘c (RÆ¡i Nhanh)";
                                }
                                else if (row == 1)
                                {
                                    rowBit = -AuxSpeedRunning;
                                    rowLabel = "âš¡ TÄƒng Tá»‘c Cháº¡y x3 (Gia Tá»‘c)";
                                }
                                else
                                {
                                    rowLabel = row == 2 ? "â†º KhÃ´i Phá»¥c CÃ i Äáº·t Máº·c Äá»‹nh" : "âœ– ÄÃ³ng Menu (áº¨n Giao Diá»‡n)";
                                }
                            }
                            bool showToggle = rowBit != 0;
                            bool isRowActive = false;
                            if (showToggle)
                            {
                                if (rowBit == NoRecoil)
                                {
                                    isRowActive = (state & NoRecoil) != 0;
                                }
                                else if (activeTab == 2)
                                {
                                    isRowActive = (vipMask & rowBit) != 0;
                                }
                                else if (rowBit < 0)
                                {
                                    isRowActive = (auxState & -rowBit) != 0;
                                }
                                else if (rowBit <= EspFov)
                                {
                                    isRowActive = (mask & rowBit) != 0;
                                }
                                else
                                {
                                    isRowActive = (state & rowBit) != 0;
                                }
                            }

                            // Ná»n hÃ ng chá»©c nÄƒng
                            GUI.color = new Color(0.062f, 0.072f, 0.105f, 0.94f);
                            GUI.DrawTexture(rowRect, pixel);

                            // Viá»n má»ng xung quanh hÃ ng
                            GUI.color = new Color(0.16f, 0.20f, 0.28f, 0.6f);
                            GUI.DrawTexture(new Rect(rowRect.x, rowRect.y, rowRect.width, 1f), pixel);
                            GUI.DrawTexture(new Rect(rowRect.x, rowRect.y + rowRect.height - 1f, rowRect.width, 1f), pixel);
                            GUI.DrawTexture(new Rect(rowRect.x, rowRect.y, 1f, rowRect.height), pixel);
                            GUI.DrawTexture(new Rect(rowRect.x + rowRect.width - 1f, rowRect.y, 1f, rowRect.height), pixel);

                            // Dáº£i Ä‘Ã¨n led chá»‰ bÃ¡o tráº¡ng thÃ¡i bÃªn trÃ¡i
                            GUI.color = isRowActive
                                ? new Color(1.0f, 0.48f, 0.05f, 1f)
                                : new Color(0.0f, 0.85f, 1.0f, 0.35f);
                            GUI.DrawTexture(new Rect(rowRect.x, rowRect.y + 2f, 4f, rowRect.height - 4f), pixel);

                            // NhÃ£n chá»¯
                            GUI.color = isRowActive
                                ? new Color(1.0f, 0.95f, 0.88f, 1f)
                                : new Color(0.70f, 0.76f, 0.84f, 1f);
                            GUI.Label(new Rect(
                                rowRect.x + 18f, rowRect.y + (rowRect.height - 24f) * 0.5f,
                                rowRect.width - (showToggle ? 110f : (activeTab == 1 && row == 5 ? 200f : (activeTab == 1 && row == 6 ? 70f : 30f))), 24f),
                                rowLabel);
                            if (activeTab == 1 && row == 5)
                            {
                                float miniTrackW = Mathf.Clamp(rowRect.width * 0.22f, 110f, 180f);
                                float miniTrackH = 14f;
                                float miniTrackY = rowRect.y + (rowRect.height - miniTrackH) * 0.5f;
                                Rect miniTrack = new Rect(rowRect.x + rowRect.width - miniTrackW - 16f, miniTrackY, miniTrackW, miniTrackH);
                                GUI.color = new Color(0.10f, 0.12f, 0.16f, 1f);
                                GUI.DrawTexture(miniTrack, pixel);
                                float fovRatio = Mathf.Clamp01((fovRadius - 40f) / 460f);
                                float miniFill = Mathf.Clamp(fovRatio * miniTrack.width, 2f, miniTrack.width);
                                GUI.color = new Color(1.0f, 0.50f, 0.05f, 1f);
                                GUI.DrawTexture(new Rect(miniTrack.x, miniTrack.y, miniFill, miniTrack.height), pixel);
                                GUI.color = new Color(0.24f, 0.30f, 0.42f, 0.8f);
                                GUI.DrawTexture(new Rect(miniTrack.x, miniTrack.y, miniTrack.width, 1f), pixel);
                                GUI.DrawTexture(new Rect(miniTrack.x, miniTrack.y + miniTrack.height - 1f, miniTrack.width, 1f), pixel);
                                GUI.DrawTexture(new Rect(miniTrack.x, miniTrack.y, 1f, miniTrack.height), pixel);
                                GUI.DrawTexture(new Rect(miniTrack.x + miniTrack.width - 1f, miniTrack.y, 1f, miniTrack.height), pixel);
                                float miniKnobX = miniTrack.x + fovRatio * (miniTrack.width - 10f);
                                GUI.color = Color.white;
                                GUI.DrawTexture(new Rect(miniKnobX, miniTrack.y - 3f, 10f, 20f), pixel);
                            }
                            else if (activeTab == 1 && row == 6)
                            {
                                float swBoxW = 38f;
                                float swBoxH = 22f;
                                float swBoxY = rowRect.y + (rowRect.height - swBoxH) * 0.5f;
                                Rect swBoxRect = new Rect(rowRect.x + rowRect.width - swBoxW - 16f, swBoxY, swBoxW, swBoxH);
                                GUI.color = isRainbow
                                    ? new Color(0.95f, 0.4f, 0.85f, 1f)
                                    : new Color((float)customR / 255f, (float)customG / 255f, (float)customB / 255f, 1f);
                                GUI.DrawTexture(swBoxRect, pixel);
                                GUI.color = Color.white;
                                GUI.DrawTexture(new Rect(swBoxRect.x, swBoxRect.y, swBoxRect.width, 1f), pixel);
                                GUI.DrawTexture(new Rect(swBoxRect.x, swBoxRect.y + swBoxRect.height - 1f, swBoxRect.width, 1f), pixel);
                                GUI.DrawTexture(new Rect(swBoxRect.x, swBoxRect.y, 1f, swBoxRect.height), pixel);
                                GUI.DrawTexture(new Rect(swBoxRect.x + swBoxRect.width - 1f, swBoxRect.y, 1f, swBoxRect.height), pixel);
                            }

                            if (showToggle)
                            {
                                bool enabled = isRowActive;
                                float tW = 70f;
                                float tH = 32f;
                                float tY = rowRect.y + (rowRect.height - tH) * 0.5f;
                                Rect track = new Rect(
                                    rowRect.x + rowRect.width - tW - 16f,
                                    tY, tW, tH);

                                // Ná»n track cÃ´ng táº¯c
                                GUI.color = enabled
                                    ? new Color(0.25f, 0.12f, 0.02f, 0.95f)
                                    : new Color(0.10f, 0.12f, 0.16f, 0.95f);
                                GUI.DrawTexture(track, pixel);

                                // Viá»n track cÃ´ng táº¯c phÃ¡t sÃ¡ng
                                GUI.color = enabled
                                    ? new Color(1.0f, 0.48f, 0.05f, 1f)
                                    : new Color(0.24f, 0.28f, 0.36f, 1f);
                                GUI.DrawTexture(new Rect(track.x, track.y, track.width, 1.2f), pixel);
                                GUI.DrawTexture(new Rect(track.x, track.y + track.height - 1.2f, track.width, 1.2f), pixel);
                                GUI.DrawTexture(new Rect(track.x, track.y, 1.2f, track.height), pixel);
                                GUI.DrawTexture(new Rect(track.x + track.width - 1.2f, track.y, 1.2f, track.height), pixel);

                                // Chá»¯ ON / OFF nhá»
                                GUI.color = enabled
                                    ? new Color(1.0f, 0.65f, 0.1f, 0.9f)
                                    : new Color(0.40f, 0.45f, 0.55f, 0.7f);
                                float textX = enabled ? track.x + 9f : track.x + 35f;
                                GUI.Label(new Rect(textX, track.y + 7f, 26f, 18f), enabled ? "ON" : "OFF");

                                // NÃºt gáº¡t nÄƒng lÆ°á»£ng (Cyber Core Node)
                                float knobX = enabled ? track.x + track.width - 29f : track.x + 4f;
                                GUI.color = enabled
                                    ? new Color(1.0f, 0.92f, 0.60f, 1f)
                                    : new Color(0.50f, 0.58f, 0.68f, 1f);
                                GUI.DrawTexture(new Rect(knobX, track.y + 3f, 26f, 26f), pixel);
                            }
                        }

                        // 4 TAB chuyá»ƒn Ä‘á»•i
                        // Tab 0: ESP
                        GUI.color = activeTab == 0
                            ? new Color(0.10f, 0.18f, 0.28f, 1f)
                            : new Color(0.045f, 0.055f, 0.08f, 1f);
                        GUI.DrawTexture(espTab, pixel);
                        if (activeTab == 0)
                        {
                            GUI.color = new Color(0.0f, 0.95f, 1.0f, 1f);
                            GUI.DrawTexture(new Rect(espTab.x, espTab.y, espTab.width, 3f), pixel);
                        }
                        GUI.color = activeTab == 0
                            ? new Color(0.0f, 0.95f, 1.0f, 1f)
                            : new Color(0.60f, 0.68f, 0.78f, 1f);
                        GUI.Label(new Rect(
                            espTab.x + espTab.width * 0.5f - 45f,
                            espTab.y + (footerHeight - 24f) * 0.5f, 90f, 24f), "ðŸ‘ ESP");

                        // Tab 1: AIM
                        GUI.color = activeTab == 1
                            ? new Color(0.24f, 0.14f, 0.05f, 1f)
                            : new Color(0.045f, 0.055f, 0.08f, 1f);
                        GUI.DrawTexture(aimTab, pixel);
                        if (activeTab == 1)
                        {
                            GUI.color = new Color(1.0f, 0.55f, 0.1f, 1f);
                            GUI.DrawTexture(new Rect(aimTab.x, aimTab.y, aimTab.width, 3f), pixel);
                        }
                        GUI.color = activeTab == 1
                            ? new Color(1.0f, 0.65f, 0.2f, 1f)
                            : new Color(0.60f, 0.68f, 0.78f, 1f);
                        GUI.Label(new Rect(
                            aimTab.x + aimTab.width * 0.5f - 45f,
                            aimTab.y + (footerHeight - 24f) * 0.5f, 90f, 24f), "ðŸŽ¯ AIM");

                        // Tab 2: VIP
                        GUI.color = activeTab == 2
                            ? new Color(0.26f, 0.20f, 0.04f, 1f)
                            : new Color(0.045f, 0.055f, 0.08f, 1f);
                        GUI.DrawTexture(vipTab, pixel);
                        if (activeTab == 2)
                        {
                            GUI.color = new Color(1.0f, 0.85f, 0.15f, 1f);
                            GUI.DrawTexture(new Rect(vipTab.x, vipTab.y, vipTab.width, 3f), pixel);
                        }
                        GUI.color = activeTab == 2
                            ? new Color(1.0f, 0.88f, 0.25f, 1f)
                            : new Color(0.60f, 0.68f, 0.78f, 1f);
                        GUI.Label(new Rect(
                            vipTab.x + vipTab.width * 0.5f - 45f,
                            vipTab.y + (footerHeight - 24f) * 0.5f, 90f, 24f), "ðŸ‘‘ VIP");

                        // Tab 3: CÃ€I Äáº¶T
                        GUI.color = activeTab == 3
                            ? new Color(0.18f, 0.10f, 0.24f, 1f)
                            : new Color(0.045f, 0.055f, 0.08f, 1f);
                        GUI.DrawTexture(settingsTab, pixel);
                        if (activeTab == 3)
                        {
                            GUI.color = new Color(0.85f, 0.35f, 1.0f, 1f);
                            GUI.DrawTexture(new Rect(settingsTab.x, settingsTab.y, settingsTab.width, 3f), pixel);
                        }
                        GUI.color = activeTab == 3
                            ? new Color(0.92f, 0.50f, 1.0f, 1f)
                            : new Color(0.60f, 0.68f, 0.78f, 1f);
                        GUI.Label(new Rect(
                            settingsTab.x + settingsTab.width * 0.5f - 50f,
                            settingsTab.y + (footerHeight - 24f) * 0.5f, 100f, 24f), "âš™ CÃ€I Äáº¶T");

                        if (activeModal != ModalNone)
                        {
                            float popupWidth = Mathf.Clamp(panelWidth - 24f, 340f, 460f);
                            float popupHeight = activeModal == ModalAimMode ? 220f
                                : (activeModal == ModalHeadRate ? 320f
                                : (activeModal == ModalFovSize ? 264f
                                : (activeModal == ModalFovColor ? 414f : 166f)));
                            float popupX = panelX + (panelWidth - popupWidth) * 0.5f;
                            float popupY = panelY + (panelHeight - popupHeight) * 0.5f;
                            Rect popupRect = new Rect(popupX, popupY, popupWidth, popupHeight);
                            Rect popupHeaderRect = new Rect(popupX, popupY, popupWidth, 42f);
                            Rect popupCloseRect = new Rect(popupX + popupWidth - 42f, popupY + 6f, 32f, 32f);

                            // 1. Lá»›p phá»§ má» tá»‘i ná»n
                            GUI.color = new Color(0.02f, 0.03f, 0.05f, 0.82f);
                            GUI.DrawTexture(panelRect, pixel);

                            // 2. Ná»n popup Cyberpunk
                            GUI.color = new Color(0.065f, 0.075f, 0.11f, 0.98f);
                            GUI.DrawTexture(popupRect, pixel);

                            // 3. Viá»n phÃ¡t sÃ¡ng Neon Cam Chakra (2px)
                            GUI.color = new Color(1.0f, 0.48f, 0.05f, 1f);
                            GUI.DrawTexture(new Rect(popupX, popupY, popupWidth, 2f), pixel);
                            GUI.DrawTexture(new Rect(popupX, popupY + popupHeight - 2f, popupWidth, 2f), pixel);
                            GUI.DrawTexture(new Rect(popupX, popupY, 2f, popupHeight), pixel);
                            GUI.DrawTexture(new Rect(popupX + popupWidth - 2f, popupY, 2f, popupHeight), pixel);

                            // 4. GÃ³c vÃ¡t cÃ´ng nghá»‡ Cyberpunk (4 gÃ³c)
                            GUI.color = new Color(0.0f, 0.95f, 1.0f, 1f);
                            GUI.DrawTexture(new Rect(popupX - 1f, popupY - 1f, 14f, 2.5f), pixel);
                            GUI.DrawTexture(new Rect(popupX - 1f, popupY - 1f, 2.5f, 14f), pixel);
                            GUI.DrawTexture(new Rect(popupX + popupWidth - 13f, popupY - 1f, 14f, 2.5f), pixel);
                            GUI.DrawTexture(new Rect(popupX + popupWidth - 1.5f, popupY - 1f, 2.5f, 14f), pixel);
                            GUI.DrawTexture(new Rect(popupX - 1f, popupY + popupHeight - 1.5f, 14f, 2.5f), pixel);
                            GUI.DrawTexture(new Rect(popupX - 1f, popupY + popupHeight - 13f, 2.5f, 14f), pixel);
                            GUI.DrawTexture(new Rect(popupX + popupWidth - 13f, popupY + popupHeight - 1.5f, 14f, 2.5f), pixel);
                            GUI.DrawTexture(new Rect(popupX + popupWidth - 1.5f, popupY + popupHeight - 13f, 2.5f, 14f), pixel);

                            // 5. Thanh tiÃªu Ä‘á» Header
                            GUI.color = new Color(0.09f, 0.10f, 0.15f, 1f);
                            GUI.DrawTexture(popupHeaderRect, pixel);
                            GUI.color = new Color(0.0f, 0.95f, 1.0f, 1f);
                            GUI.DrawTexture(new Rect(popupX, popupY + 41f, popupWidth, 1.5f), pixel);

                            // TiÃªu Ä‘á»
                            GUI.color = new Color(0.0f, 0.95f, 1.0f, 1f);
                            string modalTitle = activeModal == ModalAimMode ? "â˜…  CHá»ŒN Vá»Š TRÃ GÄ‚M TÃ‚M  â˜…"
                                : (activeModal == ModalHeadRate ? "â˜…  CHá»ŒN Tá»¶ Lá»† TRÃšNG Äáº¦U  â˜…"
                                : (activeModal == ModalFovSize ? "â˜…  THANH CUá»˜N Cá»  VÃ’NG FOV  â˜…"
                                : (activeModal == ModalFovColor ? "â˜…  Báº¢NG MÃ€U FOV Tá»° CHá»ŒN (CUSTOM)  â˜…"
                                : (activeModal == ModalSystemTarget ? "â˜…  CHá»ŒN Vá»Š TRÃ KÃ‰O TÃ‚M  â˜…"
                                : "â˜…  CHá»ŒN Gá»C DÃ‚Y ESP LINE  â˜…"))));
                            GUI.Label(new Rect(popupX + 16f, popupY + 10f, popupWidth - 60f, 22f), modalTitle);

                            // NÃºt Ä‘Ã³ng âœ•
                            GUI.color = new Color(0.85f, 0.12f, 0.18f, 1f);
                            GUI.DrawTexture(popupCloseRect, pixel);
                            GUI.color = Color.white;
                            GUI.Label(new Rect(popupCloseRect.x + 10f, popupCloseRect.y + 6f, 18f, 18f), "âœ•");

                            if (activeModal == ModalFovColor)
                            {
                                // LIVE PREVIEW CARD
                                Rect previewCard = new Rect(popupX + 14f, popupY + 48f, popupWidth - 28f, 54f);
                                GUI.color = new Color(0.04f, 0.05f, 0.08f, 0.95f);
                                GUI.DrawTexture(previewCard, pixel);
                                GUI.color = new Color(0.18f, 0.22f, 0.32f, 0.8f);
                                GUI.DrawTexture(new Rect(previewCard.x, previewCard.y, previewCard.width, 1.2f), pixel);
                                GUI.DrawTexture(new Rect(previewCard.x, previewCard.y + previewCard.height - 1.2f, previewCard.width, 1.2f), pixel);
                                GUI.DrawTexture(new Rect(previewCard.x, previewCard.y, 1.2f, previewCard.height), pixel);
                                GUI.DrawTexture(new Rect(previewCard.x + previewCard.width - 1.2f, previewCard.y, 1.2f, previewCard.height), pixel);

                                // Swatch box
                                Rect swatchRect = new Rect(previewCard.x + 8f, previewCard.y + 7f, 65f, 40f);
                                Color curCol = isRainbow ? new Color(0.95f, 0.4f, 0.85f) : new Color((float)customR / 255f, (float)customG / 255f, (float)customB / 255f);
                                GUI.color = curCol;
                                GUI.DrawTexture(swatchRect, pixel);
                                GUI.color = Color.white;
                                GUI.DrawTexture(new Rect(swatchRect.x, swatchRect.y, swatchRect.width, 1.2f), pixel);
                                GUI.DrawTexture(new Rect(swatchRect.x, swatchRect.y + swatchRect.height - 1.2f, swatchRect.width, 1.2f), pixel);
                                GUI.DrawTexture(new Rect(swatchRect.x, swatchRect.y, 1.2f, swatchRect.height), pixel);
                                GUI.DrawTexture(new Rect(swatchRect.x + swatchRect.width - 1.2f, swatchRect.y, 1.2f, swatchRect.height), pixel);
                                // TÃ¢m crosshair nhá» trong swatch
                                float cx = swatchRect.x + swatchRect.width * 0.5f;
                                float cy = swatchRect.y + swatchRect.height * 0.5f;
                                GUI.color = (customR + customG + customB > 450) ? Color.black : Color.white;
                                GUI.DrawTexture(new Rect(cx - 6f, cy - 0.75f, 12f, 1.5f), pixel);
                                GUI.DrawTexture(new Rect(cx - 0.75f, cy - 6f, 1.5f, 12f), pixel);

                                // Label mÃ£ mÃ u / tráº¡ng thÃ¡i
                                GUI.color = new Color(0.0f, 0.95f, 1.0f, 1f);
                                string hex = customR.ToString("X2") + customG.ToString("X2") + customB.ToString("X2");
                                GUI.Label(new Rect(previewCard.x + 82f, previewCard.y + 7f, previewCard.width - 90f, 20f),
                                    isRainbow ? "CHáº¾ Äá»˜: ðŸŒˆ Cáº¦U Vá»’NG RGB 7 MÃ€U (Äá»˜NG)" : ("MÃƒ MÃ€U: #" + hex + "  |  RGB(" + customR + ", " + customG + ", " + customB + ")"));
                                GUI.color = new Color(0.70f, 0.75f, 0.85f, 0.9f);
                                GUI.Label(new Rect(previewCard.x + 82f, previewCard.y + 27f, previewCard.width - 90f, 20f),
                                    isRainbow ? "VÃ²ng FOV tá»± xoay Ä‘á»•i dáº£i 7 mÃ u nhÆ° bÃ n phÃ­m Gaming" : "Cháº¡m/kÃ©o thanh R-G-B hoáº·c báº¥m mÃ u nhanh phÃ­a dÆ°á»›i");

                                // 3 SLIDERS R - G - B
                                for (int ch = 0; ch < 3; ch++)
                                {
                                    float sY = popupY + 110f + (float)ch * 42f;
                                    Rect sRowRect = new Rect(popupX + 14f, sY, popupWidth - 28f, 38f);
                                    GUI.color = new Color(0.05f, 0.06f, 0.09f, 0.92f);
                                    GUI.DrawTexture(sRowRect, pixel);
                                    GUI.color = new Color(0.14f, 0.17f, 0.24f, 0.6f);
                                    GUI.DrawTexture(new Rect(sRowRect.x, sRowRect.y, sRowRect.width, 1f), pixel);
                                    GUI.DrawTexture(new Rect(sRowRect.x, sRowRect.y + sRowRect.height - 1f, sRowRect.width, 1f), pixel);
                                    GUI.DrawTexture(new Rect(sRowRect.x, sRowRect.y, 1f, sRowRect.height), pixel);
                                    GUI.DrawTexture(new Rect(sRowRect.x + sRowRect.width - 1f, sRowRect.y, 1f, sRowRect.height), pixel);

                                    int chVal = ch == 0 ? customR : (ch == 1 ? customG : customB);
                                    string chName = ch == 0 ? "ðŸ”´ Äá»Ž (R)" : (ch == 1 ? "ðŸŸ¢ Lá»¤C (G)" : "ðŸ”µ LAM (B)");
                                    Color chColor = ch == 0 ? new Color(1.0f, 0.28f, 0.32f, 1f) : (ch == 1 ? new Color(0.25f, 1.0f, 0.4f, 1f) : new Color(0.25f, 0.72f, 1.0f, 1f));
                                    GUI.color = chColor;
                                    GUI.DrawTexture(new Rect(sRowRect.x, sRowRect.y + 2f, 4f, sRowRect.height - 4f), pixel);
                                    GUI.Label(new Rect(sRowRect.x + 10f, sRowRect.y + 8f, 110f, 22f), chName + ": " + chVal);

                                    // Slider track
                                    Rect trackRect = new Rect(popupX + 126f, sY + 11f, popupWidth - 146f, 16f);
                                    GUI.color = new Color(0.12f, 0.14f, 0.18f, 1f);
                                    GUI.DrawTexture(trackRect, pixel);
                                    float fillW = Mathf.Clamp(((float)chVal / 255f) * trackRect.width, 2f, trackRect.width);
                                    GUI.color = chColor;
                                    GUI.DrawTexture(new Rect(trackRect.x, trackRect.y, fillW, trackRect.height), pixel);
                                    GUI.color = new Color(0.28f, 0.32f, 0.42f, 1f);
                                    GUI.DrawTexture(new Rect(trackRect.x, trackRect.y, trackRect.width, 1f), pixel);
                                    GUI.DrawTexture(new Rect(trackRect.x, trackRect.y + trackRect.height - 1f, trackRect.width, 1f), pixel);
                                    GUI.DrawTexture(new Rect(trackRect.x, trackRect.y, 1f, trackRect.height), pixel);
                                    GUI.DrawTexture(new Rect(trackRect.x + trackRect.width - 1f, trackRect.y, 1f, trackRect.height), pixel);

                                    // Slider knob
                                    float knobX = trackRect.x + ((float)chVal / 255f) * (trackRect.width - 12f);
                                    Rect knobRect = new Rect(knobX, trackRect.y - 4f, 12f, 24f);
                                    GUI.color = Color.white;
                                    GUI.DrawTexture(knobRect, pixel);
                                    GUI.color = new Color(0.1f, 0.1f, 0.1f, 1f);
                                    GUI.DrawTexture(new Rect(knobRect.x + 4f, knobRect.y + 4f, 4f, 16f), pixel);
                                }

                                // Báº¢NG MÃ€U CHá»ŒN NHANH (10 swatches)
                                float swStartY = popupY + 242f;
                                GUI.color = new Color(0.0f, 0.95f, 1.0f, 1f);
                                GUI.Label(new Rect(popupX + 14f, swStartY, popupWidth - 28f, 18f), "âš¡ Báº¢NG MÃ€U CHá»ŒN NHANH & CHáº¾ Äá»˜ Cáº¦U Vá»’NG:");
                                float swW = (popupWidth - 28f - 4 * 6f) / 5f;
                                float swH = 30f;
                                for (int sw = 0; sw < 10; sw++)
                                {
                                    int swRow = sw / 5;
                                    int swCol = sw % 5;
                                    Rect swRect = new Rect(popupX + 14f + (float)swCol * (swW + 6f), swStartY + 20f + (float)swRow * (swH + 5f), swW, swH);
                                    string swName = sw == 0 ? "Äá»Ž" : (sw == 1 ? "VÃ€NG" : (sw == 2 ? "Lá»¤C" : (sw == 3 ? "CYAN" : (sw == 4 ? "LAM" : (sw == 5 ? "TÃM" : (sw == 6 ? "Há»’NG" : (sw == 7 ? "CAM" : (sw == 8 ? "TRáº®NG" : "ðŸŒˆ 7 MÃ€U"))))))));
                                    Color swC = sw == 0 ? new Color(1.0f, 0.15f, 0.2f)
                                        : (sw == 1 ? new Color(1.0f, 0.92f, 0.05f)
                                        : (sw == 2 ? new Color(0.1f, 1.0f, 0.35f)
                                        : (sw == 3 ? new Color(0.0f, 0.95f, 1.0f)
                                        : (sw == 4 ? new Color(0.15f, 0.5f, 1.0f)
                                        : (sw == 5 ? new Color(0.7f, 0.15f, 1.0f)
                                        : (sw == 6 ? new Color(1.0f, 0.15f, 0.65f)
                                        : (sw == 7 ? new Color(1.0f, 0.5f, 0.0f)
                                        : (sw == 8 ? Color.white : new Color(1.0f, 0.85f, 0.2f)))))))));

                                    bool isCurrentSw = sw == 9 ? isRainbow : (!isRainbow && Mathf.Abs(customR - (int)(swC.r * 255f)) < 15 && Mathf.Abs(customG - (int)(swC.g * 255f)) < 15 && Mathf.Abs(customB - (int)(swC.b * 255f)) < 15);
                                    GUI.color = isCurrentSw ? new Color(0.15f, 0.18f, 0.24f, 0.95f) : new Color(0.06f, 0.07f, 0.10f, 0.92f);
                                    GUI.DrawTexture(swRect, pixel);
                                    GUI.color = isCurrentSw ? new Color(1.0f, 0.65f, 0.1f, 1f) : new Color(0.20f, 0.24f, 0.32f, 0.7f);
                                    GUI.DrawTexture(new Rect(swRect.x, swRect.y, swRect.width, 1.2f), pixel);
                                    GUI.DrawTexture(new Rect(swRect.x, swRect.y + swRect.height - 1.2f, swRect.width, 1.2f), pixel);
                                    GUI.DrawTexture(new Rect(swRect.x, swRect.y, 1.2f, swRect.height), pixel);
                                    GUI.DrawTexture(new Rect(swRect.x + swRect.width - 1.2f, swRect.y, 1.2f, swRect.height), pixel);

                                    // Block mÃ u nhá» bÃªn trÃ¡i
                                    GUI.color = swC;
                                    GUI.DrawTexture(new Rect(swRect.x + 4f, swRect.y + 4f, 12f, swH - 8f), pixel);
                                    // Chá»¯ tÃªn mÃ u
                                    GUI.color = isCurrentSw ? Color.white : new Color(0.80f, 0.85f, 0.92f, 0.9f);
                                    GUI.Label(new Rect(swRect.x + 18f, swRect.y + 5f, swW - 20f, 20f), swName);
                                }

                                // NÃšT ÃP Dá»¤NG & ÄÃ“NG
                                Rect applyBtn = new Rect(popupX + 14f, popupY + 352f, popupWidth - 28f, 42f);
                                GUI.color = new Color(0.10f, 0.32f, 0.18f, 0.96f);
                                GUI.DrawTexture(applyBtn, pixel);
                                GUI.color = new Color(0.25f, 0.95f, 0.45f, 1f);
                                GUI.DrawTexture(new Rect(applyBtn.x, applyBtn.y, applyBtn.width, 1.5f), pixel);
                                GUI.DrawTexture(new Rect(applyBtn.x, applyBtn.y + applyBtn.height - 1.5f, applyBtn.width, 1.5f), pixel);
                                GUI.DrawTexture(new Rect(applyBtn.x, applyBtn.y, 1.5f, applyBtn.height), pixel);
                                GUI.DrawTexture(new Rect(applyBtn.x + applyBtn.width - 1.5f, applyBtn.y, 1.5f, applyBtn.height), pixel);
                                GUI.color = Color.white;
                                GUI.Label(new Rect(applyBtn.x + applyBtn.width * 0.5f - 90f, applyBtn.y + 10f, 180f, 22f), "âœ”  ÃP Dá»¤NG & ÄÃ“NG Báº¢NG MÃ€U");
                            }
                            else if (activeModal == ModalFovSize)
                            {
                                // THÃ”NG TIN KÃCH THÆ¯á»šC FOV HIá»†N Táº I
                                Rect previewCard = new Rect(popupX + 14f, popupY + 48f, popupWidth - 28f, 54f);
                                GUI.color = new Color(0.04f, 0.05f, 0.08f, 0.95f);
                                GUI.DrawTexture(previewCard, pixel);
                                GUI.color = new Color(0.18f, 0.22f, 0.32f, 0.8f);
                                GUI.DrawTexture(new Rect(previewCard.x, previewCard.y, previewCard.width, 1.2f), pixel);
                                GUI.DrawTexture(new Rect(previewCard.x, previewCard.y + previewCard.height - 1.2f, previewCard.width, 1.2f), pixel);
                                GUI.DrawTexture(new Rect(previewCard.x, previewCard.y, 1.2f, previewCard.height), pixel);
                                GUI.DrawTexture(new Rect(previewCard.x + previewCard.width - 1.2f, previewCard.y, 1.2f, previewCard.height), pixel);

                                // Dáº£i led cam
                                GUI.color = new Color(1.0f, 0.50f, 0.05f, 1f);
                                GUI.DrawTexture(new Rect(previewCard.x, previewCard.y + 2f, 4f, previewCard.height - 4f), pixel);

                                string fovDesc = fovRadius < 85f ? "SiÃªu KÃ­n (Báº¯n Giáº£i)"
                                    : (fovRadius < 125f ? "KÃ­n ÄÃ¡o (Tá»± NhiÃªn)"
                                    : (fovRadius < 170f ? "Chuáº©n (CÃ¢n Báº±ng)"
                                    : (fovRadius < 250f ? "Rá»™ng (Dá»… Báº¯n)" : "Cá»±c Äáº¡i (ToÃ n MÃ n)")));

                                GUI.color = new Color(1.0f, 0.65f, 0.15f, 1f);
                                GUI.Label(new Rect(previewCard.x + 14f, previewCard.y + 7f, previewCard.width - 20f, 20f),
                                    "ðŸ“ BÃN KÃNH VÃ’NG FOV: " + Mathf.RoundToInt(fovRadius) + "px  (" + fovDesc + ")");
                                GUI.color = new Color(0.70f, 0.78f, 0.88f, 0.9f);
                                GUI.Label(new Rect(previewCard.x + 14f, previewCard.y + 27f, previewCard.width - 20f, 20f),
                                    "KÃ©o trÆ°á»£t thanh ngang hoáº·c báº¥m nÃºt bÃªn dÆ°á»›i Ä‘á»ƒ Ä‘á»•i cá»¡ (40px â†’ 400px)");

                                // THANH CUá»˜N TRÆ¯á»¢T NGANG (SLIDER)
                                Rect sRowRect = new Rect(popupX + 14f, popupY + 110f, popupWidth - 28f, 42f);
                                GUI.color = new Color(0.05f, 0.06f, 0.09f, 0.92f);
                                GUI.DrawTexture(sRowRect, pixel);
                                GUI.color = new Color(0.14f, 0.17f, 0.24f, 0.6f);
                                GUI.DrawTexture(new Rect(sRowRect.x, sRowRect.y, sRowRect.width, 1f), pixel);
                                GUI.DrawTexture(new Rect(sRowRect.x, sRowRect.y + sRowRect.height - 1f, sRowRect.width, 1f), pixel);
                                GUI.DrawTexture(new Rect(sRowRect.x, sRowRect.y, 1f, sRowRect.height), pixel);
                                GUI.DrawTexture(new Rect(sRowRect.x + sRowRect.width - 1f, sRowRect.y, 1f, sRowRect.height), pixel);

                                GUI.color = new Color(0.60f, 0.68f, 0.78f, 1f);
                                GUI.Label(new Rect(sRowRect.x + 12f, sRowRect.y + 11f, 50f, 22f), "40px");

                                Rect fovTrack = new Rect(popupX + 72f, popupY + 120f, popupWidth - 144f, 22f);
                                GUI.color = new Color(0.12f, 0.14f, 0.18f, 1f);
                                GUI.DrawTexture(fovTrack, pixel);
                                float fovRatio = Mathf.Clamp01((fovRadius - 40f) / 460f);
                                float fillW = Mathf.Clamp(fovRatio * fovTrack.width, 3f, fovTrack.width);
                                GUI.color = new Color(1.0f, 0.50f, 0.05f, 1f);
                                GUI.DrawTexture(new Rect(fovTrack.x, fovTrack.y, fillW, fovTrack.height), pixel);
                                GUI.color = new Color(0.28f, 0.32f, 0.42f, 1f);
                                GUI.DrawTexture(new Rect(fovTrack.x, fovTrack.y, fovTrack.width, 1f), pixel);
                                GUI.DrawTexture(new Rect(fovTrack.x, fovTrack.y + fovTrack.height - 1f, fovTrack.width, 1f), pixel);
                                GUI.DrawTexture(new Rect(fovTrack.x, fovTrack.y, 1f, fovTrack.height), pixel);
                                GUI.DrawTexture(new Rect(fovTrack.x + fovTrack.width - 1f, fovTrack.y, 1f, fovTrack.height), pixel);

                                // Slider knob
                                float knobX = fovTrack.x + fovRatio * (fovTrack.width - 16f);
                                Rect knobRect = new Rect(knobX, fovTrack.y - 4f, 16f, 30f);
                                GUI.color = Color.white;
                                GUI.DrawTexture(knobRect, pixel);
                                GUI.color = new Color(1.0f, 0.48f, 0.05f, 1f);
                                GUI.DrawTexture(new Rect(knobRect.x + 6f, knobRect.y + 4f, 4f, 22f), pixel);

                                GUI.color = new Color(0.60f, 0.68f, 0.78f, 1f);
                                GUI.Label(new Rect(popupX + popupWidth - 62f, sRowRect.y + 11f, 50f, 22f), "400px");

                                // CÃC NÃšT BÆ¯á»šC NHáº¢Y & PHÃM Táº®T NHANH
                                float btnRowW = popupWidth - 28f;
                                float stepBtnW = 46f;
                                Rect decBtn = new Rect(popupX + 14f, popupY + 160f, stepBtnW, 34f);
                                GUI.color = new Color(0.08f, 0.10f, 0.14f, 0.95f);
                                GUI.DrawTexture(decBtn, pixel);
                                GUI.color = new Color(0.25f, 0.30f, 0.42f, 0.8f);
                                GUI.DrawTexture(new Rect(decBtn.x, decBtn.y, decBtn.width, 1.2f), pixel);
                                GUI.DrawTexture(new Rect(decBtn.x, decBtn.y + decBtn.height - 1.2f, decBtn.width, 1.2f), pixel);
                                GUI.DrawTexture(new Rect(decBtn.x, decBtn.y, 1.2f, decBtn.height), pixel);
                                GUI.DrawTexture(new Rect(decBtn.x + decBtn.width - 1.2f, decBtn.y, 1.2f, decBtn.height), pixel);
                                GUI.color = new Color(0.85f, 0.90f, 0.98f, 1f);
                                GUI.Label(new Rect(decBtn.x + 8f, decBtn.y + 7f, stepBtnW - 16f, 20f), "-10px");

                                Rect incBtn = new Rect(popupX + 14f + btnRowW - stepBtnW, popupY + 160f, stepBtnW, 34f);
                                GUI.color = new Color(0.08f, 0.10f, 0.14f, 0.95f);
                                GUI.DrawTexture(incBtn, pixel);
                                GUI.color = new Color(0.25f, 0.30f, 0.42f, 0.8f);
                                GUI.DrawTexture(new Rect(incBtn.x, incBtn.y, incBtn.width, 1.2f), pixel);
                                GUI.DrawTexture(new Rect(incBtn.x, incBtn.y + incBtn.height - 1.2f, incBtn.width, 1.2f), pixel);
                                GUI.DrawTexture(new Rect(incBtn.x, incBtn.y, 1.2f, incBtn.height), pixel);
                                GUI.DrawTexture(new Rect(incBtn.x + incBtn.width - 1.2f, incBtn.y, 1.2f, incBtn.height), pixel);
                                GUI.color = new Color(0.85f, 0.90f, 0.98f, 1f);
                                GUI.Label(new Rect(incBtn.x + 8f, incBtn.y + 7f, stepBtnW - 16f, 20f), "+10px");

                                float presetW = (btnRowW - stepBtnW * 2f - 24f) / 5f;
                                for (int p = 0; p < 5; p++)
                                {
                                    float pVal = p == 0 ? 90f : (p == 1 ? 140f : (p == 2 ? 250f : (p == 3 ? 360f : 500f)));
                                    Rect pRect = new Rect(popupX + 14f + stepBtnW + 4f + (float)p * (presetW + 4f), popupY + 160f, presetW, 34f);
                                    bool isPreSel = Mathf.Abs(fovRadius - pVal) < 5f;
                                    GUI.color = isPreSel ? new Color(0.20f, 0.14f, 0.08f, 0.95f) : new Color(0.08f, 0.10f, 0.14f, 0.92f);
                                    GUI.DrawTexture(pRect, pixel);
                                    GUI.color = isPreSel ? new Color(1.0f, 0.52f, 0.08f, 1f) : new Color(0.20f, 0.24f, 0.34f, 0.65f);
                                    GUI.DrawTexture(new Rect(pRect.x, pRect.y, pRect.width, 1.2f), pixel);
                                    GUI.DrawTexture(new Rect(pRect.x, pRect.y + pRect.height - 1.2f, pRect.width, 1.2f), pixel);
                                    GUI.DrawTexture(new Rect(pRect.x, pRect.y, 1.2f, pRect.height), pixel);
                                    GUI.DrawTexture(new Rect(pRect.x + pRect.width - 1.2f, pRect.y, 1.2f, pRect.height), pixel);
                                    GUI.color = isPreSel ? Color.white : new Color(0.75f, 0.82f, 0.90f, 0.9f);
                                    GUI.Label(new Rect(pRect.x + 2f, pRect.y + 7f, presetW - 4f, 20f), ((int)pVal).ToString() + "px");
                                }

                                // NÃšT ÃP Dá»¤NG & ÄÃ“NG
                                Rect fovApplyBtn = new Rect(popupX + 14f, popupY + 208f, popupWidth - 28f, 42f);
                                GUI.color = new Color(0.10f, 0.32f, 0.18f, 0.96f);
                                GUI.DrawTexture(fovApplyBtn, pixel);
                                GUI.color = new Color(0.25f, 0.95f, 0.45f, 1f);
                                GUI.DrawTexture(new Rect(fovApplyBtn.x, fovApplyBtn.y, fovApplyBtn.width, 1.5f), pixel);
                                GUI.DrawTexture(new Rect(fovApplyBtn.x, fovApplyBtn.y + fovApplyBtn.height - 1.5f, fovApplyBtn.width, 1.5f), pixel);
                                GUI.DrawTexture(new Rect(fovApplyBtn.x, fovApplyBtn.y, 1.5f, fovApplyBtn.height), pixel);
                                GUI.DrawTexture(new Rect(fovApplyBtn.x + fovApplyBtn.width - 1.5f, fovApplyBtn.y, 1.5f, fovApplyBtn.height), pixel);
                                GUI.color = Color.white;
                                GUI.Label(new Rect(fovApplyBtn.x + fovApplyBtn.width * 0.5f - 100f, fovApplyBtn.y + 10f, 200f, 22f), "âœ”  ÃP Dá»¤NG & ÄÃ“NG THANH CUá»˜N");
                            }
                            else
                            {
                                float optStartY = popupY + 48f;
                                float optRowHeight = 46f;
                                float optSpacing = 6f;
                                int optCount = activeModal == ModalAimMode ? 3
                                    : (activeModal == ModalHeadRate ? 5 : 2);

                                for (int i = 0; i < optCount; i++)
                                {
                                    Rect optRect = new Rect(popupX + 14f, optStartY + (float)i * (optRowHeight + optSpacing), popupWidth - 28f, optRowHeight);
                                    bool isSelected = false;
                                    string optText = "";
                                    if (activeModal == ModalAimMode)
                                    {
                                        isSelected = (aimMode == i);
                                        optText = i == 0 ? "ðŸŽ¯ Ngá»±c / ThÃ¢n (An ToÃ n, á»”n Äá»‹nh)"
                                            : (i == 1 ? "ðŸŽ¯ Äáº§u - Headshot (Háº¡ Äá»‹ch Cá»±c Nhanh)" : "ðŸŽ¯ Äa Äiá»ƒm - Random (KÃ­n ÄÃ¡o, Chá»‘ng Soi)");
                                    }
                                    else if (activeModal == ModalHeadRate)
                                    {
                                        isSelected = (headRateIndex == i);
                                        optText = i == 0 ? "âš¡ 0% (KhÃ´ng Headshot - Báº¯n Chuáº©n ThÃ¢n)"
                                            : (i == 1 ? "âš¡ 25% (Headshot Tháº¥p - Ráº¥t Tá»± NhiÃªn)"
                                            : (i == 2 ? "âš¡ 50% (Headshot Vá»«a - CÃ¢n Báº±ng)"
                                            : (i == 3 ? "âš¡ 75% (Headshot Cao - Dá»… Gank Team)" : "âš¡ 100% (Full Äá» - BÃ¡ Äáº¡o)")));
                                    }
                                    else if (activeModal == ModalSystemTarget)
                                    {
                                        isSelected = (i == 1 ? (state & AimSystemHead) != 0 : (state & AimSystemHead) == 0);
                                        optText = i == 0 ? "ðŸŽ¯ KÃ©o TÃ¢m VÃ o Cá»• (Tá»± NhiÃªn)" : "ðŸŽ¯ KÃ©o TÃ¢m VÃ o Äáº§u (Headshot)";
                                    }
                                    else if (activeModal == ModalTracerOrigin)
                                    {
                                        isSelected = (i == 1 ? isBottomTracer : !isBottomTracer);
                                        optText = i == 0
                                            ? "ðŸ“ Äá»‰nh MÃ n HÃ¬nh (Tá»« TrÃªn Xuá»‘ng - Máº·c Äá»‹nh)"
                                            : "ðŸ“ ÄÃ¡y MÃ n HÃ¬nh (Tá»« DÆ°á»›i LÃªn - Chuáº©n GÃ³c NhÃ¬n)";
                                    }

                                    // Ná»n option
                                    GUI.color = isSelected
                                        ? new Color(0.14f, 0.11f, 0.08f, 0.98f)
                                        : new Color(0.06f, 0.07f, 0.10f, 0.95f);
                                    GUI.DrawTexture(optRect, pixel);

                                    // Viá»n option
                                    GUI.color = isSelected
                                        ? new Color(1.0f, 0.52f, 0.08f, 1f)
                                        : new Color(0.18f, 0.22f, 0.30f, 0.65f);
                                    GUI.DrawTexture(new Rect(optRect.x, optRect.y, optRect.width, 1.2f), pixel);
                                    GUI.DrawTexture(new Rect(optRect.x, optRect.y + optRect.height - 1.2f, optRect.width, 1.2f), pixel);
                                    GUI.DrawTexture(new Rect(optRect.x, optRect.y, 1.2f, optRect.height), pixel);
                                    GUI.DrawTexture(new Rect(optRect.x + optRect.width - 1.2f, optRect.y, 1.2f, optRect.height), pixel);

                                    // ÄÃ¨n led tráº¡ng thÃ¡i bÃªn trÃ¡i
                                    GUI.color = isSelected
                                        ? new Color(1.0f, 0.48f, 0.05f, 1f)
                                        : new Color(0.0f, 0.85f, 1.0f, 0.3f);
                                    GUI.DrawTexture(new Rect(optRect.x, optRect.y + 2f, 4f, optRect.height - 4f), pixel);

                                    // KÃ½ hiá»‡u chá»n [â—] hoáº·c [â—‹]
                                    GUI.color = isSelected
                                        ? new Color(1.0f, 0.65f, 0.2f, 1f)
                                        : new Color(0.4f, 0.48f, 0.58f, 0.8f);
                                    GUI.Label(new Rect(optRect.x + 12f, optRect.y + 12f, 24f, 22f), isSelected ? "â—" : "â—‹");

                                    // NhÃ£n chá»¯ option
                                    GUI.color = isSelected
                                        ? new Color(1.0f, 0.94f, 0.82f, 1f)
                                        : new Color(0.80f, 0.85f, 0.92f, 0.9f);
                                    GUI.Label(new Rect(optRect.x + 36f, optRect.y + 12f, optRect.width - 48f, 22f), optText);
                                }
                            }
                        }
                    }

                    if (false && !menuOpen && (state & StateAuthorized) != 0)
                    {
                        GUI.matrix = Matrix4x4.identity;
                        GUI.color = new Color(0.04f, 0.05f, 0.08f, 0.92f);
                        GUI.DrawTexture(toggleBadgeRect, pixel);
                        GUI.color = new Color(1.0f, 0.46f, 0.05f, 0.95f);
                        GUI.DrawTexture(new Rect(16f, 16f, 110f, 2f), pixel);
                        GUI.DrawTexture(new Rect(16f, 48f, 110f, 2f), pixel);
                        GUI.DrawTexture(new Rect(16f, 16f, 2f, 34f), pixel);
                        GUI.DrawTexture(new Rect(124f, 16f, 2f, 34f), pixel);
                        GUI.color = new Color(0.0f, 0.95f, 1.0f, 1f);
                        GUI.Label(new Rect(22f, 22f, 100f, 22f), "âš¡ PROXY VIP");
                    }
                    // MÃ n hÃ¬nh cháº©n Ä‘oÃ¡n chÆ°a kÃ­ch hoáº¡t Ä‘Ã£ Ä‘Æ°á»£c váº½ an toÃ n á»Ÿ Ä‘áº§u Repaint

                }
            }
            catch (Exception)
            {
                // A transient Unity object is skipped for this event.
            }

            GUI.matrix = savedMatrix;
            GUI.color = savedColor;
        }

        public static {{AIM_INFO_TYPE}} SilentAim(Player self)
        {
            if (self == null)
            {
                return null;
            }
            {{AIM_INFO_TYPE}} info = self.{{PLAYER_AIM_INFO_FIELD}};
            if (info == null)
            {
                return info;
            }
            try
            {
                if (!self.IsLocalPlayer())
                {
                    return info;
                }
                GameObject driver = GameObject.Find("__esp_driver");
                if (driver == null)
                {
                    Camera cam = Camera.main;
                    Transform legacyFov = cam == null ? null : cam.transform.Find("__esp_fov");
                    if (legacyFov != null)
                    {
                        UnityEngine.Object.Destroy(legacyFov.gameObject);
                    }
                    driver = new GameObject("__esp_driver");
                    driver.transform.localScale = new Vector3(0f, (float)(1 | (1 << 19) | (0 << 3) | (245 << 11)), (float)(255 << 4));
                    SceneEditBoxSelectTool tool = (SceneEditBoxSelectTool)driver.AddComponent(typeof(SceneEditBoxSelectTool));
                    if (tool != null)
                    {
                        UnityEngine.Object.DontDestroyOnLoad(driver);
                    }
                }
                SceneEditBoxSelectTool menu = driver == null
                    ? null
                    : (SceneEditBoxSelectTool)driver.GetComponent(typeof(SceneEditBoxSelectTool));
            int state = menu == null ? 0 : (int)menu.{{SCENE_STATE_FIELD}}.x;
            if ((state & StateAuthorized) == 0)
            {
                return info;
            }

            int vipMask = driver != null ? ((int)driver.transform.localScale.z & 15) : 0;
            PlayerAttributes myAttributes = self.Attributes;
            if (myAttributes != null)
            {
                if ((state & NoRecoil) != 0)
                {
                    myAttributes.SkillScatterRate = -1f;
                    myAttributes.SkillScatterRateSighting = -1f;
                }
                else if (myAttributes.SkillScatterRate < -0.5f)
                {
                    myAttributes.SkillScatterRate = 0f;
                    myAttributes.SkillScatterRateSighting = 0f;
                }

                if ((vipMask & VipFastFire) != 0)
                {
                    myAttributes.FireIntervalScale = 0.35f;
                }
                else if (myAttributes.FireIntervalScale < 0.9f)
                {
                    myAttributes.FireIntervalScale = 1.0f;
                }

                if ((vipMask & VipHeadDamage) != 0)
                {
                    myAttributes.HeadDamageIncreaseScale = 10000.0f;
                    myAttributes.BuffWeaponDamageScale = 10000.0f;
                    myAttributes.DamageAdditionScale = 10000.0f;
                    myAttributes.ExecuteDamageScale = 10000.0f;
                }
                else if (myAttributes.HeadDamageIncreaseScale > 10.0f)
                {
                    myAttributes.HeadDamageIncreaseScale = 0f;
                    myAttributes.BuffWeaponDamageScale = 0f;
                    myAttributes.DamageAdditionScale = 0f;
                    myAttributes.ExecuteDamageScale = 0f;
                }
            }

            bool isAimSilent = (state & AimEnabled) != 0;
            if (!isAimSilent)
            {
                return info;
            }

            {{MATCH_TYPE}} match = GameFacade.CurrentMatch();
            IList players = match == null ? null : match.{{MATCH_PLAYERS_METHOD}}();
            Camera camera = Camera.main;
            if (camera == null)
            {
                Camera[] cams = Camera.allCameras;
                if (cams != null && cams.Length > 0)
                {
                    camera = cams[0];
                }
            }
            if (players == null || camera == null)
            {
                return info;
            }

            int aimMode = (state & AimModeMask) >> AimModeShift;
            int headRate = ((state & HeadRateMask) >> HeadRateShift) * 25;
            vipMask = driver != null ? ((int)driver.transform.localScale.z & 15) : 0;
            bool isFakeDmg = (vipMask & VipHeadDamage) != 0;

            // Aim Silent target: uses headshot rate %
            bool aimAtHead = isFakeDmg || aimMode == 1
                || (aimMode == 2 && UnityEngine.Random.Range(0, 100) < headRate);

            Vector3 aimStart = self.AimStartPostion;
            float fovLockRadius = 140f;
            if (driver != null)
            {
                float storedZ = driver.transform.position.z;
                if (storedZ >= 10f && storedZ <= 600f)
                {
                    fovLockRadius = storedZ;
                }
            }
            float maxFovScore = fovLockRadius * fovLockRadius;
            Collider bestVisibleCollider = null;
            Vector3 bestVisiblePosition = Vector3.zero;
            float bestVisibleScore = maxFovScore + 1f;

            Collider bestWallCollider = null;
            Vector3 bestWallPosition = Vector3.zero;
            float bestWallScore = maxFovScore + 1f;

            for (int index = 0; index < players.Count; index++)
            {
                Player candidate = players[index] as Player;
                GameObject candidateObject = candidate == null ? null : candidate.gameObject;
                if (candidateObject == null || !candidateObject.activeInHierarchy
                    || candidate.IsLocalPlayer()
                    || candidate.CurHP <= 0
                    || candidate.IsLocalTeammate(false)
                    || candidate.IsLocalTeammate(true))
                {
                    continue;
                }

                Transform root = candidate.RootTransform;
                Transform head = candidate.GetHeadTF();
                Collider headCollider = candidate.HeadCollider;
                if (root == null)
                {
                    continue;
                }

                Vector3 hitPosition;
                Collider hitCollider = null;
                if (aimAtHead)
                {
                    if (head != null)
                    {
                        hitPosition = head.position;
                    }
                    else
                    {
                        hitPosition = root.position + new Vector3(0f, 1.65f, 0f);
                    }

                    if (headCollider != null)
                    {
                        hitCollider = headCollider;
                    }
                    else
                    {
                        hitCollider = (Collider)root.GetComponent("CapsuleCollider");
                        if (hitCollider == null)
                        {
                            hitCollider = (Collider)candidateObject.GetComponent(typeof(Collider));
                        }
                    }
                }
                else
                {
                    if (head != null)
                    {
                        hitPosition = head.position - new Vector3(0f, 0.22f, 0f);
                    }
                    else
                    {
                        hitPosition = root.position + new Vector3(0f, 1.25f, 0f);
                    }
                    hitCollider = (Collider)root.GetComponent("CapsuleCollider");
                    if (hitCollider == null)
                    {
                        hitCollider = headCollider;
                        if (hitCollider == null)
                        {
                            hitCollider = (Collider)candidateObject.GetComponent(typeof(Collider));
                        }
                    }
                }

                if (hitCollider == null)
                {
                    continue;
                }

                float maxAimDist = isFakeDmg ? 600f : 500f;
                if (Vector3.Distance(hitPosition, aimStart) > maxAimDist)
                {
                    continue;
                }
                Vector3 screen = camera.WorldToScreenPoint(hitPosition);
                if (screen.z <= 1f
                    || float.IsNaN(screen.x) || float.IsNaN(screen.y)
                    || float.IsNaN(screen.z) || float.IsInfinity(screen.x)
                    || float.IsInfinity(screen.y) || float.IsInfinity(screen.z))
                {
                    continue;
                }
                float dx = screen.x - (float)Screen.width * 0.5f;
                float dy = screen.y - (float)Screen.height * 0.5f;
                float score = dx * dx + dy * dy;
                if (float.IsNaN(score) || float.IsInfinity(score)
                    || score > maxFovScore
                    || (score >= bestVisibleScore && score >= bestWallScore))
                {
                    continue;
                }

                Vector3 toTarget = hitPosition - aimStart;
                float targetDist = toTarget.magnitude;
                bool isVisible = true;
                if (targetDist > 1.2f)
                {
                    Vector3 rayDir = toTarget / targetDist;
                    Vector3 rayOrigin = aimStart + rayDir * 0.4f;
                    float rayDist = targetDist - 0.7f;
                    if (rayDist > 0.1f)
                    {
                        RaycastHit hit;
                        if (Physics.Raycast(rayOrigin, rayDir, out hit, rayDist, -1, QueryTriggerInteraction.Ignore))
                        {
                            if (hit.collider != null && !hit.collider.isTrigger)
                            {
                                Transform hitTf = hit.transform;
                                if (hitTf != null)
                                {
                                    Transform hitRoot = hitTf.root;
                                    Transform candRoot = candidateObject != null ? candidateObject.transform.root : null;
                                    Transform selfRoot = self.gameObject != null ? self.gameObject.transform.root : null;
                                    if (hitRoot != candRoot && hitRoot != selfRoot)
                                    {
                                        isVisible = false;
                                    }
                                }
                                else
                                {
                                    isVisible = false;
                                }
                            }
                        }
                    }
                }

                if (isVisible)
                {
                    if (score < bestVisibleScore)
                    {
                        bestVisibleScore = score;
                        bestVisibleCollider = hitCollider;
                        bestVisiblePosition = hitPosition;
                    }
                }
                else
                {
                    if (score < bestWallScore)
                    {
                        bestWallScore = score;
                        bestWallCollider = hitCollider;
                        bestWallPosition = hitPosition;
                    }
                }
            }

            Collider bestCollider = bestVisibleCollider != null ? bestVisibleCollider : bestWallCollider;
            Vector3 bestPosition = bestVisibleCollider != null ? bestVisiblePosition : bestWallPosition;

            if (bestCollider != null)
            {
                Vector3 rayDirection = Vector3.Normalize(bestPosition - aimStart);
                info.{{AIM_GAME_OBJECT_FIELD}} = bestCollider.gameObject;
                info.{{AIM_COLLIDER_FIELD}} = bestCollider;
                info.{{AIM_HIT_POSITION_FIELD}} = bestPosition;
                info.{{AIM_TRACE_POSITION_FIELD}} = bestPosition;
                info.{{AIM_DIRECTION_FIELD}} = rayDirection;
                info.{{AIM_ORIGIN_FIELD}} = aimStart;
                info.{{AIM_SECONDARY_ORIGIN_FIELD}} = aimStart;
                info.{{AIM_HIT_TYPE_FIELD}} = ({{AIM_HIT_TYPE}})1;
                info.{{AIM_FLAG_A_FIELD}} = false;
                info.{{AIM_FLAG_B_FIELD}} = false;
                info.{{AIM_SHORT_FIELD}} = (short)0;
            }
            return info;
        }
        catch (Exception)
        {
            return info;
        }
        }

        public static bool AimSystem(Player self)
        {
            if (self == null)
            {
                return false;
            }
            try
            {
                return self.EspBaseIsMovableEntity();
            }
            catch (Exception)
            {
                return false;
            }
        }



        public static float ScatterRate(PlayerAttributes self)
        {
            if (self == null)
            {
                return 1f;
            }
            try
            {
                if (self.SkillScatterRate < -0.5f || self.SkillScatterRateSighting < -0.5f)
                {
                    return 0f;
                }
                GameObject driver = GameObject.Find("__esp_driver");
                if (driver == null)
                {
                    Camera cam = Camera.main;
                    Transform legacyFov = cam == null ? null : cam.transform.Find("__esp_fov");
                    if (legacyFov != null)
                    {
                        UnityEngine.Object.Destroy(legacyFov.gameObject);
                    }
                    driver = new GameObject("__esp_driver");
                    driver.transform.localScale = new Vector3(0f, (float)(1 | (1 << 19) | (0 << 3) | (245 << 11)), (float)(255 << 4));
                    SceneEditBoxSelectTool tool = (SceneEditBoxSelectTool)driver.AddComponent(typeof(SceneEditBoxSelectTool));
                    if (tool != null)
                    {
                        UnityEngine.Object.DontDestroyOnLoad(driver);
                    }
                }
                SceneEditBoxSelectTool menu = driver == null
                    ? null
                    : (SceneEditBoxSelectTool)driver.GetComponent(typeof(SceneEditBoxSelectTool));
                int state = menu == null ? 0 : (int)menu.{{SCENE_STATE_FIELD}}.x;
                if ((state & StateAuthorized) != 0 && (state & NoRecoil) != 0)
                {
                    self.SkillScatterRate = -1f;
                    self.SkillScatterRateSighting = -1f;
                    return 0f;
                }
                float skillBonus = self.SkillScatterRate;
                float normalRate = 1f + skillBonus;
                if (normalRate < 0.1f)
                {
                    normalRate = 1f;
                }
                return normalRate;
            }
            catch (Exception)
            {
                return 1f;
            }
        }
    }
}
