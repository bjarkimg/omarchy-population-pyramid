import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "bmg.population-pyramid"

  property bool popupOpen: false
  readonly property bool opened: popupOpen

  property var dataset: null
  property string selectedCountryCode: "KOR" // Default to South Korea (canonical decline case)
  property string selectedYear: "2026"
  property bool isPlaying: false
  property string searchQuery: ""
  property bool showingSearchList: false
  // Hover previews a country; click pins it until the same flag is clicked again.
  property bool countryLocked: false

  readonly property var countryList: {
    if (!dataset || !dataset.countries) return []
    var list = []
    for (var code in dataset.countries) {
      list.push(dataset.countries[code])
    }
    return list
  }

  readonly property var filteredCountries: {
    var q = searchQuery.trim().toLowerCase()
    if (!q) return countryList
    return countryList.filter(function(c) {
      return c.name.toLowerCase().indexOf(q) >= 0 || c.code.toLowerCase().indexOf(q) >= 0
    })
  }

  readonly property var currentCountry: (dataset && dataset.countries && dataset.countries[selectedCountryCode])
    ? dataset.countries[selectedCountryCode]
    : (countryList.length > 0 ? countryList[0] : null)

  // Year grid comes from the active country trajectory so scrubbing matches its exact zero horizon
  readonly property int currentYear: (dataset && dataset.metadata && dataset.metadata.currentYear)
    ? dataset.metadata.currentYear : 2026
  readonly property var pyramidYearsList: (currentCountry && currentCountry.trajectoryYears && currentCountry.trajectoryYears.length > 0)
    ? currentCountry.trajectoryYears
    : ((dataset && dataset.metadata && dataset.metadata.pyramidYears) ? dataset.metadata.pyramidYears : [1950, 2026, 2100])

  // 42 countries categorized strictly by 2026 TFR demographic tiers
  readonly property var severityTiers: [
    {
      key: "critical",
      dot: "🔴",
      label: "RAPID DECLINE",
      range: "< 1.30",
      color: "#f87171",
      countries: [
        { code: "KOR", label: "🇰🇷 S.Korea" },
        { code: "HKG", label: "🇭🇰 Hong Kong" },
        { code: "TWN", label: "🇹🇼 Taiwan" },
        { code: "UKR", label: "🇺🇦 Ukraine" },
        { code: "SGP", label: "🇸🇬 Singapore" },
        { code: "CHN", label: "🇨🇳 China" },
        { code: "ESP", label: "🇪🇸 Spain" },
        { code: "POL", label: "🇵🇱 Poland" },
        { code: "THA", label: "🇹🇭 Thailand" },
        { code: "JPN", label: "🇯🇵 Japan" },
        { code: "ITA", label: "🇮🇹 Italy" },
        { code: "FIN", label: "🇫🇮 Finland" }
      ]
    },
    {
      key: "aging",
      dot: "🟡",
      label: "AGING / SUB-REPL",
      range: "1.30 – 2.00",
      color: "#fbbf24",
      countries: [
        { code: "GRC", label: "🇬🇷 Greece" },
        { code: "CAN", label: "🇨🇦 Canada" },
        { code: "PRT", label: "🇵🇹 Portugal" },
        { code: "DEU", label: "🇩🇪 Germany" },
        { code: "NOR", label: "🇳🇴 Norway" },
        { code: "RUS", label: "🇷🇺 Russia" },
        { code: "SWE", label: "🇸🇪 Sweden" },
        { code: "CHL", label: "🇨🇱 Chile" },
        { code: "GBR", label: "🇬🇧 UK" },
        { code: "DNK", label: "🇩🇰 Denmark" },
        { code: "TUR", label: "🇹🇷 Turkey" },
        { code: "AUS", label: "🇦🇺 Australia" },
        { code: "BRA", label: "🇧🇷 Brazil" },
        { code: "ISL", label: "🇮🇸 Iceland" },
        { code: "USA", label: "🇺🇸 USA" },
        { code: "COL", label: "🇨🇴 Colombia" },
        { code: "FRA", label: "🇫🇷 France" },
        { code: "MEX", label: "🇲🇽 Mexico" },
        { code: "ARG", label: "🇦🇷 Argentina" },
        { code: "VNM", label: "🇻🇳 Vietnam" },
        { code: "IND", label: "🇮🇳 India" }
      ]
    },
    {
      key: "growth",
      dot: "🟢",
      label: "GROWTH / GLOBAL",
      range: "≥ 2.00",
      color: "#4ade80",
      countries: [
        { code: "IDN", label: "🇮🇩 Indonesia" },
        { code: "WLD", label: "🌍 World" },
        { code: "ZAF", label: "🇿🇦 S.Africa" },
        { code: "PHL", label: "🇵🇭 Philippines" },
        { code: "EGY", label: "🇪🇬 Egypt" },
        { code: "KEN", label: "🇰🇪 Kenya" },
        { code: "PAK", label: "🇵🇰 Pakistan" },
        { code: "ETH", label: "🇪🇹 Ethiopia" },
        { code: "NGA", label: "🇳🇬 Nigeria" }
      ]
    }
  ]

  function open() {
    popupOpen = true
    dataFile.reload()
  }

  function close() {
    isPlaying = false
    showingSearchList = false
    popupOpen = false
  }

  function toggle() {
    if (popupOpen) close()
    else open()
  }

  function stepYear(delta) {
    var currentIdx = pyramidYearsList.indexOf(parseInt(selectedYear, 10))
    if (currentIdx < 0) currentIdx = Math.max(0, pyramidYearsList.indexOf(currentYear))
    var nextIdx = currentIdx + delta
    if (nextIdx >= pyramidYearsList.length) nextIdx = 0
    if (nextIdx < 0) nextIdx = pyramidYearsList.length - 1
    selectedYear = String(pyramidYearsList[nextIdx])
  }

  function togglePlay() {
    isPlaying = !isPlaying
  }

  function applyYearForCountry(code) {
    var country = (dataset && dataset.countries) ? dataset.countries[code] : null
    var years = (country && country.trajectoryYears && country.trajectoryYears.length > 0)
      ? country.trajectoryYears
      : pyramidYearsList
    var yr = parseInt(selectedYear, 10)
    if (!years || years.indexOf(yr) < 0) {
      selectedYear = String(currentYear)
    }
  }

  function applyDisplayedCountry(code) {
    if (!code || selectedCountryCode === code)
      return
    selectedCountryCode = code
    applyYearForCountry(code)
  }

  function previewCountry(code) {
    if (countryLocked)
      return
    applyDisplayedCountry(code)
  }

  function lockCountry(code) {
    applyDisplayedCountry(code)
    countryLocked = true
    showingSearchList = false
    searchQuery = ""
  }

  function toggleCountryLock(code) {
    if (countryLocked && selectedCountryCode === code) {
      countryLocked = false
      return
    }
    lockCountry(code)
  }

  function selectCountry(code) {
    lockCountry(code)
  }

  FileView {
    id: dataFile
    path: Qt.resolvedUrl("data/demographics.json").toString().replace(/^file:\/\//, "")
    watchChanges: true
    printErrors: false
    onLoaded: {
      try {
        root.dataset = JSON.parse(text())
      } catch (e) {
        console.error("Failed to parse demographics.json:", e)
      }
    }
  }

  Timer {
    id: playTimer
    interval: 400
    repeat: true
    running: root.isPlaying && root.popupOpen
    onTriggered: root.stepYear(1)
  }

  IpcHandler {
    target: "bmg.population-pyramid"
    function open(): void { root.open() }
    function close(): void { root.close() }
    function toggle(): void { root.toggle() }
    function next(): void { root.stepYear(1) }
    function prev(): void { root.stepYear(-1) }
    function setYear(yr: string): void { root.selectedYear = yr }
    function lock(code: string): void { root.lockCountry(code) }
    function unlock(): void { root.countryLocked = false }
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "󰄹"
    slotSize: Style.bar.statusSlot
    active: root.popupOpen
    tooltipText: root.currentCountry
      ? (root.currentCountry.flag + " " + root.currentCountry.name + ": " + root.currentCountry.population2026 + "M | TFR " + root.currentCountry.tfr)
      : "World Population Decline & Demographics"

    onPressed: function(b) {
      if (!root.bar) return
      if (b === Qt.RightButton) {
        if (root.currentCountry) {
          var c = root.currentCountry
          root.bar.run("notify-send 'Demographics: " + c.flag + " " + c.name + "' 'Pop: " + c.population2026 + "M | TFR: " + c.tfr + " | Peak: " + c.peakYear + (c.extinctionYear ? " | Zero: " + c.extinctionYear : "") + "'")
        }
      } else {
        root.toggle()
      }
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.popupOpen
    centerOnBar: true
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(880))
    contentHeight: panel.fittedContentHeight(mainColumn.implicitHeight + Style.space(16))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      anchors.margins: Style.space(8)
      blocked: searchInput.activeFocus

      onMoveRequested: function(dx, dy) {
        if (dx < 0) root.stepYear(-1)
        else if (dx > 0) root.stepYear(1)
      }
      onActivateRequested: root.togglePlay()
      onCloseRequested: root.close()
      onTextKey: function(text) {
        if (text === " ") {
          root.togglePlay()
        }
      }

      Column {
        id: mainColumn
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        spacing: Style.space(8)

        // =====================================================================
        // 1. TOP ROW: Left Pyramid & Stats (560px) + Right Boxed Flags (290px)
        // =====================================================================
        Row {
          id: topRow
          width: parent.width
          spacing: Style.space(10)

          // -------------------------------------------------------------------
          // TOP LEFT: Country Header, Vital Statistics & Age-Sex Pyramid
          // -------------------------------------------------------------------
          Column {
            id: topLeftColumn
            width: Style.space(470)
            spacing: Style.space(8)

            // Header Bar with Country Title
            Item {
              width: parent.width
              height: Style.space(26)

              Text {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                textFormat: Text.PlainText
                text: root.currentCountry
                  ? (root.currentCountry.flag + (root.countryLocked ? " 🔒 " : " ") + root.currentCountry.name.toUpperCase() + " (" + root.currentCountry.code + ") DEMOGRAPHICS")
                  : "POPULATION & DECLINE TRACKER"
                color: Color.accent
                font.family: Style.font.family
                font.pixelSize: Style.font.body
                font.bold: true
              }
            }

            // Country Vital Statistics Card
            Rectangle {
              width: parent.width
              height: Style.space(72)
              color: Qt.rgba(0.1, 0.15, 0.22, 0.7)
              border.color: Qt.rgba(1, 1, 1, 0.12)
              border.width: 1
              radius: 8

              Row {
                anchors.fill: parent
                anchors.margins: Style.space(6)
                spacing: Style.space(6)

                // Current Population Card
                Item {
                  width: (parent.width - Style.space(18)) / 4
                  height: parent.height

                  Column {
                    anchors.centerIn: parent
                    spacing: 1
                    Text {
                      anchors.horizontalCenter: parent.horizontalCenter
                      text: root.currentYear + " POPULATION"
                      color: Color.muted
                      font.family: Style.font.family
                      font.pixelSize: 9
                      font.bold: true
                    }
                    Text {
                      anchors.horizontalCenter: parent.horizontalCenter
                      text: root.currentCountry ? (root.currentCountry.population2026 >= 1000 ? (root.currentCountry.population2026/1000).toFixed(2) + "B" : root.currentCountry.population2026.toFixed(1) + "M") : "--"
                      color: Color.foreground
                      font.family: Style.font.family
                      font.pixelSize: 13
                      font.bold: true
                    }
                    Text {
                      anchors.horizontalCenter: parent.horizontalCenter
                      text: root.currentCountry ? (root.currentCountry.growthRate2026 > 0 ? "+" : "") + root.currentCountry.growthRate2026.toFixed(2) + "%/yr" : ""
                      color: root.currentCountry && root.currentCountry.growthRate2026 < 0 ? "#f87171" : "#4ade80"
                      font.family: Style.font.family
                      font.pixelSize: 8
                    }
                  }
                }

                // Total Fertility Rate (TFR)
                Item {
                  width: (parent.width - Style.space(18)) / 4
                  height: parent.height

                  Column {
                    anchors.centerIn: parent
                    spacing: 1
                    Text {
                      anchors.horizontalCenter: parent.horizontalCenter
                      text: "FERTILITY (TFR)"
                      color: Color.muted
                      font.family: Style.font.family
                      font.pixelSize: 9
                      font.bold: true
                    }
                    Text {
                      anchors.horizontalCenter: parent.horizontalCenter
                      text: root.currentCountry ? root.currentCountry.tfr.toFixed(2) : "--"
                      color: {
                        if (!root.currentCountry) return Color.foreground
                        if (root.currentCountry.tfr < 1.3) return "#f87171"
                        if (root.currentCountry.tfr < 2.1) return "#fbbf24"
                        return "#4ade80"
                      }
                      font.family: Style.font.family
                      font.pixelSize: 13
                      font.bold: true
                    }
                    Text {
                      anchors.horizontalCenter: parent.horizontalCenter
                      text: root.currentCountry && root.currentCountry.tfr < 2.1 ? "Sub-replacement" : "Above 2.10 Repl"
                      color: Color.muted
                      font.family: Style.font.family
                      font.pixelSize: 8
                    }
                  }
                }

                // Peak Population Year
                Item {
                  width: (parent.width - Style.space(18)) / 4
                  height: parent.height

                  Column {
                    anchors.centerIn: parent
                    spacing: 1
                    Text {
                      anchors.horizontalCenter: parent.horizontalCenter
                      text: "PEAK YEAR"
                      color: Color.muted
                      font.family: Style.font.family
                      font.pixelSize: 9
                      font.bold: true
                    }
                    Text {
                      anchors.horizontalCenter: parent.horizontalCenter
                      text: root.currentCountry ? String(root.currentCountry.peakYear) : "--"
                      color: root.currentCountry && root.currentCountry.peakYear <= root.currentYear ? "#f87171" : "#38bdf8"
                      font.family: Style.font.family
                      font.pixelSize: 13
                      font.bold: true
                    }
                    Text {
                      anchors.horizontalCenter: parent.horizontalCenter
                      text: root.currentCountry ? (root.currentCountry.peakPopulation >= 1000 ? (root.currentCountry.peakPopulation/1000).toFixed(2) + "B" : root.currentCountry.peakPopulation.toFixed(1) + "M peak") : ""
                      color: Color.muted
                      font.family: Style.font.family
                      font.pixelSize: 8
                    }
                  }
                }

                // Path to Zero / Extinction Horizon
                Item {
                  width: (parent.width - Style.space(18)) / 4
                  height: parent.height

                  Column {
                    anchors.centerIn: parent
                    spacing: 1
                    Text {
                      anchors.horizontalCenter: parent.horizontalCenter
                      text: root.currentCountry && root.currentCountry.isSubReplacement ? "PATH TO ZERO" : "100Y GROWTH"
                      color: Color.muted
                      font.family: Style.font.family
                      font.pixelSize: 9
                      font.bold: true
                    }
                    Text {
                      anchors.horizontalCenter: parent.horizontalCenter
                      text: root.currentCountry ? (root.currentCountry.isSubReplacement ? ("~0: Yr " + root.currentCountry.extinctionYear) : ("Yr 2126: " + (root.currentCountry.pop2100 >= 1000 ? (root.currentCountry.pop2100/1000).toFixed(1) + "B" : root.currentCountry.pop2100.toFixed(0) + "M"))) : "--"
                      color: root.currentCountry && root.currentCountry.isSubReplacement ? "#f43f5e" : "#4ade80"
                      font.family: Style.font.family
                      font.pixelSize: 13
                      font.bold: true
                    }
                    Text {
                      anchors.horizontalCenter: parent.horizontalCenter
                      text: root.currentCountry && root.currentCountry.isSubReplacement ? ("T½ Halving: Yr " + root.currentCountry.halvingYear) : "Expanding population"
                      color: Color.muted
                      font.family: Style.font.family
                      font.pixelSize: 8
                    }
                  }
                }
              }
            }

            // Vertical Age-Sex Population Pyramid
            PopulationPyramid {
              width: parent.width
              countryData: root.currentCountry
              selectedYear: root.selectedYear
            }
          }

          // -------------------------------------------------------------------
          // TOP RIGHT: Boxed-In Flag Directory Card
          // -------------------------------------------------------------------
          Rectangle {
            id: topRightBox
            width: Math.max(Style.space(280), topRow.width - topLeftColumn.width - topRow.spacing)
            height: topLeftColumn.implicitHeight
            color: Qt.rgba(0.08, 0.12, 0.18, 0.75)
            border.color: Qt.rgba(1, 1, 1, 0.12)
            border.width: 1
            radius: 8
            clip: true

            Column {
              anchors.fill: parent
              anchors.margins: Style.space(6)
              spacing: Style.space(5)

              // Directory Header Bar with Close Button
              Item {
                width: parent.width
                height: Style.space(24)

                Text {
                  anchors.left: parent.left
                  anchors.verticalCenter: parent.verticalCenter
                  textFormat: Text.PlainText
                  text: root.countryLocked ? "🔒 DIRECTORY" : "🌍 DIRECTORY"
                  color: Color.accent
                  font.family: Style.font.family
                  font.pixelSize: Style.font.body
                  font.bold: true
                }

                Row {
                  anchors.right: parent.right
                  anchors.verticalCenter: parent.verticalCenter
                  spacing: Style.space(4)

                  Text {
                    anchors.verticalCenter: parent.verticalCenter
                    textFormat: Text.PlainText
                    text: root.countryLocked ? "LOCKED" : "HOVER"
                    color: root.countryLocked ? Color.accent : Color.muted
                    font.family: Style.font.family
                    font.pixelSize: Style.font.caption
                    font.bold: true
                  }

                  Button {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "✕"
                    width: Style.space(20)
                    height: Style.space(20)
                    onClicked: root.close()
                  }
                }
              }

              // Search Input
              TextField {
                id: searchInput
                width: parent.width
                placeholderText: "Search country..."
                text: root.searchQuery
                onTextChanged: {
                  root.searchQuery = text
                  root.showingSearchList = text.trim().length > 0
                }
                onAccepted: {
                  if (root.filteredCountries.length > 0) {
                    root.selectCountry(root.filteredCountries[0].code)
                  }
                }
              }

              // Search Results Overlay List (when typing in search)
              Rectangle {
                visible: root.showingSearchList
                width: parent.width
                height: parent.height - searchInput.height - Style.space(34)
                color: Qt.rgba(0.08, 0.12, 0.18, 0.95)
                border.color: Color.accent
                border.width: 1
                radius: 6
                clip: true

                Flickable {
                  id: searchFlick
                  anchors.fill: parent
                  anchors.margins: Style.space(4)
                  contentHeight: searchListCol.implicitHeight
                  clip: true
                  boundsBehavior: Flickable.StopAtBounds
                  flickableDirection: Flickable.VerticalFlick

                  Item {
                    id: searchScrollTrack
                    z: 10
                    visible: searchFlick.contentHeight > searchFlick.height
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    width: Style.space(4)

                    Rectangle {
                      anchors.fill: parent
                      color: Qt.rgba(1, 1, 1, 0.08)
                      radius: 2
                    }

                    Rectangle {
                      id: searchScrollThumb
                      width: parent.width
                      height: Math.max(16, (searchFlick.height / Math.max(1, searchFlick.contentHeight)) * parent.height)
                      y: {
                        var range = searchScrollTrack.height - height
                        var contentRange = searchFlick.contentHeight - searchFlick.height
                        if (contentRange <= 0 || range <= 0) return 0
                        return Math.max(0, Math.min(range, (searchFlick.contentY / contentRange) * range))
                      }
                      color: searchThumbMouse.containsMouse || searchThumbMouse.pressed ? Color.accent : Qt.rgba(0.95, 0.65, 0.35, 0.45)
                      radius: 2

                      Behavior on color { ColorAnimation { duration: 100 } }
                    }

                    MouseArea {
                      id: searchThumbMouse
                      anchors.fill: parent
                      hoverEnabled: true
                      cursorShape: Qt.PointingHandCursor
                      property real startY: 0
                      property real startContentY: 0

                      onPressed: function(mouse) {
                        startY = mouse.y
                        startContentY = searchFlick.contentY
                        var range = searchScrollTrack.height - searchScrollThumb.height
                        if (range > 0 && (mouse.y < searchScrollThumb.y || mouse.y > searchScrollThumb.y + searchScrollThumb.height)) {
                          var targetY = Math.max(0, Math.min(range, mouse.y - searchScrollThumb.height / 2))
                          searchFlick.contentY = (targetY / range) * (searchFlick.contentHeight - searchFlick.height)
                          startContentY = searchFlick.contentY
                        }
                      }

                      onPositionChanged: function(mouse) {
                        if (pressed) {
                          var range = searchScrollTrack.height - searchScrollThumb.height
                          if (range > 0) {
                            var delta = mouse.y - startY
                            var contentRange = searchFlick.contentHeight - searchFlick.height
                            var newContentY = startContentY + (delta / range) * contentRange
                            searchFlick.contentY = Math.max(0, Math.min(contentRange, newContentY))
                          }
                        }
                      }
                    }
                  }

                  WheelHandler {
                    onWheel: function(event) {
                      var dy = event.angleDelta.y
                      if (dy === 0) dy = event.pixelDelta.y
                      var step = Math.round(dy * 0.5)
                      var maxY = Math.max(0, searchFlick.contentHeight - searchFlick.height)
                      searchFlick.contentY = Math.max(0, Math.min(maxY, searchFlick.contentY - step))
                      event.accepted = true
                    }
                  }

                  Column {
                    id: searchListCol
                    width: parent.width - (searchFlick.contentHeight > searchFlick.height ? Style.space(6) : 0)
                    spacing: 2

                    Repeater {
                      model: root.filteredCountries
                      CountryFlagButton {
                        width: parent.width
                        height: Style.space(22)
                        countryCode: modelData.code
                        countryLabel: modelData.flag + " " + modelData.name + " (" + modelData.code + ")  ·  TFR " + modelData.tfr.toFixed(2)
                        bordered: false
                        locked: root.countryLocked
                        current: modelData.code === root.selectedCountryCode
                        onPreviewRequested: function(code) { root.previewCountry(code) }
                        onLockToggled: function(code) { root.toggleCountryLock(code) }
                        onWheelScrolled: function(wheel) {
                          var dy = wheel.angleDelta.y
                          if (dy === 0) dy = wheel.pixelDelta.y
                          var step = Math.round(dy * 0.5)
                          var maxY = Math.max(0, searchFlick.contentHeight - searchFlick.height)
                          searchFlick.contentY = Math.max(0, Math.min(maxY, searchFlick.contentY - step))
                          wheel.accepted = true
                        }
                      }
                    }
                  }
                }
              }

              // 3 Side-by-Side Vertical Columns (1 per Severity Tier)
              Row {
                visible: !root.showingSearchList
                width: parent.width
                height: parent.height - searchInput.height - Style.space(34)
                spacing: Style.space(3)

                Repeater {
                  model: root.severityTiers

                  Column {
                    id: tierColumn
                    readonly property var tier: modelData
                    width: (parent.width - Style.space(6)) / 3
                    height: parent.height
                    spacing: Style.space(3)

                    // Tier Column Header
                    Rectangle {
                      width: parent.width
                      height: Style.space(26)
                      color: Qt.rgba(0.1, 0.14, 0.2, 0.8)
                      border.color: Qt.rgba(1, 1, 1, 0.08)
                      radius: 4

                      Column {
                        anchors.centerIn: parent
                        spacing: 1

                        Text {
                          anchors.horizontalCenter: parent.horizontalCenter
                          text: tierColumn.tier.dot + " " + (tierColumn.tier.key === "critical" ? "CRITICAL" : tierColumn.tier.key === "aging" ? "AGING" : "GROWTH")
                          color: tierColumn.tier.color
                          font.family: Style.font.family
                          font.pixelSize: 8
                          font.bold: true
                        }

                        Text {
                          anchors.horizontalCenter: parent.horizontalCenter
                          text: "TFR " + tierColumn.tier.range
                          color: Color.muted
                          font.family: Style.font.family
                          font.pixelSize: 7
                        }
                      }
                    }

                    // Vertical list of countries in this tier
                    Flickable {
                      id: countryFlick
                      width: parent.width
                      height: parent.height - Style.space(30)
                      contentHeight: countryBtnCol.implicitHeight
                      clip: true
                      boundsBehavior: Flickable.StopAtBounds
                      flickableDirection: Flickable.VerticalFlick

                      // Custom interactive scroll track & thumb
                      Item {
                        id: scrollTrack
                        z: 10
                        visible: countryFlick.contentHeight > countryFlick.height
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        width: Style.space(4)

                        // Subtle track background
                        Rectangle {
                          anchors.fill: parent
                          color: Qt.rgba(1, 1, 1, 0.08)
                          radius: 2
                        }

                        // Scroll thumb
                        Rectangle {
                          id: scrollThumb
                          width: parent.width
                          height: Math.max(24, (countryFlick.height / Math.max(1, countryFlick.contentHeight)) * parent.height)
                          y: {
                            var range = scrollTrack.height - height
                            var contentRange = countryFlick.contentHeight - countryFlick.height
                            if (contentRange <= 0 || range <= 0) return 0
                            return Math.max(0, Math.min(range, (countryFlick.contentY / contentRange) * range))
                          }
                          color: thumbMouse.containsMouse || thumbMouse.pressed ? Color.accent : Qt.rgba(0.95, 0.65, 0.35, 0.45)
                          radius: 2

                          Behavior on color { ColorAnimation { duration: 100 } }
                        }

                        MouseArea {
                          id: thumbMouse
                          anchors.fill: parent
                          hoverEnabled: true
                          cursorShape: Qt.PointingHandCursor
                          property real startY: 0
                          property real startContentY: 0

                          onPressed: function(mouse) {
                            startY = mouse.y
                            startContentY = countryFlick.contentY
                            var range = scrollTrack.height - scrollThumb.height
                            if (range > 0 && (mouse.y < scrollThumb.y || mouse.y > scrollThumb.y + scrollThumb.height)) {
                              var targetY = Math.max(0, Math.min(range, mouse.y - scrollThumb.height / 2))
                              countryFlick.contentY = (targetY / range) * (countryFlick.contentHeight - countryFlick.height)
                              startContentY = countryFlick.contentY
                            }
                          }

                          onPositionChanged: function(mouse) {
                            if (pressed) {
                              var range = scrollTrack.height - scrollThumb.height
                              if (range > 0) {
                                var delta = mouse.y - startY
                                var contentRange = countryFlick.contentHeight - countryFlick.height
                                var newContentY = startContentY + (delta / range) * contentRange
                                countryFlick.contentY = Math.max(0, Math.min(contentRange, newContentY))
                              }
                            }
                          }
                        }
                      }

                      WheelHandler {
                        onWheel: function(event) {
                          var dy = event.angleDelta.y
                          if (dy === 0) dy = event.pixelDelta.y
                          var step = Math.round(dy * 0.5)
                          var maxY = Math.max(0, countryFlick.contentHeight - countryFlick.height)
                          countryFlick.contentY = Math.max(0, Math.min(maxY, countryFlick.contentY - step))
                          event.accepted = true
                        }
                      }

                      Column {
                        id: countryBtnCol
                        width: parent.width - (countryFlick.contentHeight > countryFlick.height ? Style.space(6) : 0)
                        spacing: 2

                        Repeater {
                          model: tierColumn.tier.countries

                          CountryFlagButton {
                            width: parent.width
                            height: Style.space(20)
                            countryCode: modelData.code
                            countryLabel: modelData.label
                            bordered: true
                            fontSize: 8
                            horizontalPadding: Style.space(4)
                            locked: root.countryLocked
                            current: modelData.code === root.selectedCountryCode
                            onPreviewRequested: function(code) { root.previewCountry(code) }
                            onLockToggled: function(code) { root.toggleCountryLock(code) }
                            onWheelScrolled: function(wheel) {
                              var dy = wheel.angleDelta.y
                              if (dy === 0) dy = wheel.pixelDelta.y
                              var step = Math.round(dy * 0.5)
                              var maxY = Math.max(0, countryFlick.contentHeight - countryFlick.height)
                              countryFlick.contentY = Math.max(0, Math.min(maxY, countryFlick.contentY - step))
                              wheel.accepted = true
                            }
                          }
                        }
                      }
                    }
                  }
                }
              }
            }
          }
        }

        // =====================================================================
        // 2. BOTTOM FULL-WIDTH SECTION: Continuous Trajectory Line Chart
        // =====================================================================
        PopulationTrajectoryChart {
          width: parent.width
          countryData: root.currentCountry
          selectedYear: root.selectedYear
          onYearSelected: function(yr) {
            var yrNum = parseInt(yr, 10)
            var closest = String(root.currentYear)
            var minDiff = 9999
            for (var i = 0; i < root.pyramidYearsList.length; i++) {
              var d = Math.abs(root.pyramidYearsList[i] - yrNum)
              if (d < minDiff) {
                minDiff = d
                closest = String(root.pyramidYearsList[i])
              }
            }
            root.selectedYear = closest
          }
        }

        // =====================================================================
        // 3. FOOTER CONTROLS INSTRUCTIONS
        // =====================================================================
        Text {
          anchors.horizontalCenter: parent.horizontalCenter
          textFormat: Text.PlainText
          text: "[Hover Flag] Preview  ·  [Click Flag] Lock / Unlock  ·  [Space] Play/Pause  ·  [Hover Chart] Scrub (1950–" + (root.currentCountry ? (root.currentCountry.trajectoryEndYear || 2300) : "2300") + ")  ·  [Esc] Dismiss"
          color: Color.muted
          font.family: Style.font.family
          font.pixelSize: 9
        }
      }
    }
  }
}
