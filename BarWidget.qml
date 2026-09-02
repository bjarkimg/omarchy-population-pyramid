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

  // Year grid comes from the dataset so it cannot drift from build_data.py.
  // It matches the trajectory chart's 5-year step, plus the "now" anchor.
  readonly property int currentYear: (dataset && dataset.metadata && dataset.metadata.currentYear)
    ? dataset.metadata.currentYear : 2026
  readonly property var pyramidYearsList: (dataset && dataset.metadata && dataset.metadata.pyramidYears
    && dataset.metadata.pyramidYears.length > 0)
    ? dataset.metadata.pyramidYears
    : [1950, 1970, 1990, 2000, 2010, 2020, 2026, 2030, 2040, 2050, 2060, 2070, 2080, 2090, 2100]

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

  function selectCountry(code) {
    selectedCountryCode = code
    showingSearchList = false
    searchQuery = ""
    selectedYear = String(currentYear)
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
    contentWidth: panel.fittedContentWidth(Style.space(960))
    contentHeight: panel.fittedContentHeight(mainRow.implicitHeight + Style.space(16))

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

      Row {
        id: mainRow
        anchors.left: parent.left
        anchors.top: parent.top
        spacing: Style.space(12)

        // =====================================================================
        // LEFT MAIN PANEL: Active Country Demographics, Pyramid & Trajectory
        // =====================================================================
        Column {
          id: leftMainPanel
          width: Style.space(570)
          spacing: Style.space(8)

          // 1. Header Bar with Country Title & Close Button
          Item {
            width: parent.width
            height: Style.space(26)

            Text {
              anchors.left: parent.left
              anchors.verticalCenter: parent.verticalCenter
              text: root.currentCountry
                ? (root.currentCountry.flag + " " + root.currentCountry.name.toUpperCase() + " (" + root.currentCountry.code + ") DEMOGRAPHICS")
                : "POPULATION & DECLINE TRACKER"
              color: Color.accent
              font.family: Style.font.family
              font.pixelSize: Style.font.body
              font.bold: true
            }

            Button {
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              text: "✕"
              width: Style.space(24)
              height: Style.space(24)
              onClicked: root.close()
            }
          }

          // 2. Country Vital Statistics Card
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

          // 3. Vertical Age-Sex Population Pyramid
          PopulationPyramid {
            width: parent.width
            countryData: root.currentCountry
            selectedYear: root.selectedYear
          }

          // 4. Continuous Trajectory Line Chart (with increased vertical room)
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

          // 5. Footer navigation instructions
          Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "[Space] Play/Pause Animation  ·  [Hover Line Chart] Scrub Years  ·  [Esc] Dismiss"
            color: Color.muted
            font.family: Style.font.family
            font.pixelSize: 9
          }
        }

        // Vertical Separator Line
        Rectangle {
          width: 1
          height: leftMainPanel.implicitHeight
          color: Qt.rgba(1, 1, 1, 0.1)
        }

        // =====================================================================
        // RIGHT SIDEBAR: 3-Column Country Directory Grouped by Severity Tier
        // =====================================================================
        Column {
          id: rightSidebar
          width: Style.space(315)
          spacing: Style.space(7)

          // Sidebar Title Header
          Item {
            width: parent.width
            height: Style.space(26)

            Text {
              anchors.left: parent.left
              anchors.verticalCenter: parent.verticalCenter
              text: "🌍 DIRECTORY"
              color: Color.accent
              font.family: Style.font.family
              font.pixelSize: Style.font.body
              font.bold: true
            }

            Text {
              anchors.right: parent.right
              anchors.rightMargin: Style.space(4)
              anchors.verticalCenter: parent.verticalCenter
              text: "42 NATIONS"
              color: Color.muted
              font.family: Style.font.family
              font.pixelSize: Style.font.caption
              font.bold: true
            }
          }

          // Search Input
          TextField {
            id: searchInput
            width: parent.width
            placeholderText: "Search (e.g. Korea, ISL)..."
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
            height: Style.space(460)
            color: Qt.rgba(0.08, 0.12, 0.18, 0.95)
            border.color: Color.accent
            border.width: 1
            radius: 6
            clip: true

            Flickable {
              anchors.fill: parent
              anchors.margins: Style.space(4)
              contentHeight: searchListCol.implicitHeight
              clip: true

              Column {
                id: searchListCol
                width: parent.width
                spacing: 2

                Repeater {
                  model: root.filteredCountries
                  Button {
                    width: parent.width
                    height: Style.space(26)
                    text: modelData.flag + " " + modelData.name + " (" + modelData.code + ")  ·  TFR " + modelData.tfr.toFixed(2)
                    bordered: false
                    selected: modelData.code === root.selectedCountryCode
                    onClicked: root.selectCountry(modelData.code)
                  }
                }
              }
            }
          }

          // 3 Side-by-Side Vertical Columns (1 per Severity Tier)
          Row {
            visible: !root.showingSearchList
            width: parent.width
            height: Style.space(465)
            spacing: Style.space(4)

            Repeater {
              model: root.severityTiers

              Column {
                id: tierColumn
                readonly property var tier: modelData
                width: (parent.width - Style.space(8)) / 3
                height: parent.height
                spacing: Style.space(3)

                // Tier Column Header
                Rectangle {
                  width: parent.width
                  height: Style.space(34)
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
                      font.pixelSize: 9
                      font.bold: true
                    }

                    Text {
                      anchors.horizontalCenter: parent.horizontalCenter
                      text: "TFR " + tierColumn.tier.range
                      color: Color.muted
                      font.family: Style.font.family
                      font.pixelSize: 8
                    }
                  }
                }

                // Vertical list of countries in this tier
                Flickable {
                  width: parent.width
                  height: parent.height - Style.space(38)
                  contentHeight: countryBtnCol.implicitHeight
                  clip: true
                  boundsBehavior: Flickable.StopAtBounds

                  Column {
                    id: countryBtnCol
                    width: parent.width
                    spacing: Style.space(2)

                    Repeater {
                      model: tierColumn.tier.countries

                      Button {
                        width: parent.width
                        height: Style.space(24)
                        text: modelData.label
                        bordered: true
                        selected: modelData.code === root.selectedCountryCode
                        fontSize: 9
                        horizontalPadding: Style.space(4)
                        onClicked: root.selectCountry(modelData.code)
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
}
