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

  // 42 countries in 3 severity tiers, wrapped across 7 flag lines (2 + 3 + 2).
  // Tier colors match the TFR readout in the vital statistics card.
  readonly property var severityTiers: [
    {
      key: "critical",
      dot: "\ud83d\udd34",
      label: "ULTRA-LOW TFR / RAPID DECLINE",
      range: "< 1.3",
      color: "#f87171",
      lines: 2,
      countries: [
        { code: "KOR", label: "\ud83c\uddf0\ud83c\uddf7 S.Korea" },
        { code: "TWN", label: "\ud83c\uddf9\ud83c\uddfc Taiwan" },
        { code: "HKG", label: "\ud83c\udded\ud83c\uddf0 Hong Kong" },
        { code: "SGP", label: "\ud83c\uddf8\ud83c\uddec Singapore" },
        { code: "JPN", label: "\ud83c\uddef\ud83c\uddf5 Japan" },
        { code: "ITA", label: "\ud83c\uddee\ud83c\uddf9 Italy" },
        { code: "ESP", label: "\ud83c\uddea\ud83c\uddf8 Spain" },
        { code: "UKR", label: "\ud83c\uddfa\ud83c\udde6 Ukraine" },
        { code: "POL", label: "\ud83c\uddf5\ud83c\uddf1 Poland" },
        { code: "GRC", label: "\ud83c\uddec\ud83c\uddf7 Greece" },
        { code: "PRT", label: "\ud83c\uddf5\ud83c\uddf9 Portugal" },
        { code: "CHN", label: "\ud83c\udde8\ud83c\uddf3 China" },
        { code: "THA", label: "\ud83c\uddf9\ud83c\udded Thailand" }
      ]
    },
    {
      key: "aging",
      dot: "\ud83d\udfe1",
      label: "AGING & SUB-REPLACEMENT",
      range: "1.3 \u2013 2.0",
      color: "#fbbf24",
      lines: 3,
      countries: [
        { code: "DEU", label: "\ud83c\udde9\ud83c\uddea Germany" },
        { code: "GBR", label: "\ud83c\uddec\ud83c\udde7 UK" },
        { code: "FRA", label: "\ud83c\uddeb\ud83c\uddf7 France" },
        { code: "USA", label: "\ud83c\uddfa\ud83c\uddf8 USA" },
        { code: "CAN", label: "\ud83c\udde8\ud83c\udde6 Canada" },
        { code: "AUS", label: "\ud83c\udde6\ud83c\uddfa Australia" },
        { code: "ISL", label: "\ud83c\uddee\ud83c\uddf8 Iceland" },
        { code: "NOR", label: "\ud83c\uddf3\ud83c\uddf4 Norway" },
        { code: "SWE", label: "\ud83c\uddf8\ud83c\uddea Sweden" },
        { code: "FIN", label: "\ud83c\uddeb\ud83c\uddee Finland" },
        { code: "DNK", label: "\ud83c\udde9\ud83c\uddf0 Denmark" },
        { code: "RUS", label: "\ud83c\uddf7\ud83c\uddfa Russia" },
        { code: "BRA", label: "\ud83c\udde7\ud83c\uddf7 Brazil" },
        { code: "MEX", label: "\ud83c\uddf2\ud83c\uddfd Mexico" },
        { code: "CHL", label: "\ud83c\udde8\ud83c\uddf1 Chile" }
      ]
    },
    {
      key: "growth",
      dot: "\ud83d\udfe2",
      label: "GROWTH & GLOBAL",
      range: "\u2265 2.0",
      color: "#4ade80",
      lines: 2,
      countries: [
        { code: "WLD", label: "\ud83c\udf0d World" },
        { code: "IND", label: "\ud83c\uddee\ud83c\uddf3 India" },
        { code: "IDN", label: "\ud83c\uddee\ud83c\udde9 Indonesia" },
        { code: "VNM", label: "\ud83c\uddfb\ud83c\uddf3 Vietnam" },
        { code: "PHL", label: "\ud83c\uddf5\ud83c\udded Philippines" },
        { code: "TUR", label: "\ud83c\uddf9\ud83c\uddf7 Turkey" },
        { code: "ZAF", label: "\ud83c\uddff\ud83c\udde6 S.Africa" },
        { code: "EGY", label: "\ud83c\uddea\ud83c\uddec Egypt" },
        { code: "PAK", label: "\ud83c\uddf5\ud83c\uddf0 Pakistan" },
        { code: "NGA", label: "\ud83c\uddf3\ud83c\uddec Nigeria" },
        { code: "ETH", label: "\ud83c\uddea\ud83c\uddf9 Ethiopia" },
        { code: "KEN", label: "\ud83c\uddf0\ud83c\uddea Kenya" },
        { code: "ARG", label: "\ud83c\udde6\ud83c\uddf7 Argentina" },
        { code: "COL", label: "\ud83c\udde8\ud83c\uddf4 Colombia" }
      ]
    }
  ]

  // Split a tier into `lineCount` balanced lines: (13, 2) -> [7, 6], (15, 3) -> [5, 5, 5]
  function chunkLines(items, lineCount) {
    if (!items || items.length === 0 || lineCount < 1) return []
    var lines = []
    var base = Math.floor(items.length / lineCount)
    var extra = items.length % lineCount
    var start = 0
    for (var i = 0; i < lineCount; i++) {
      var take = base + (i < extra ? 1 : 0)
      lines.push(items.slice(start, start + take))
      start += take
    }
    return lines
  }

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
    contentWidth: panel.fittedContentWidth(Style.space(600))
    contentHeight: panel.fittedContentHeight(mainColumn.implicitHeight)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
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

        // 1. Header Bar
        Item {
          width: parent.width
          height: Style.space(26)

          Text {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: "🌍 POPULATION & DECLINE TRACKER"
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

        // 2. Country Selector & 3 Flag Lines with Scrollbar
        Column {
          width: parent.width
          spacing: Style.space(5)

          Row {
            width: parent.width
            spacing: Style.space(6)

            TextField {
              id: searchInput
              width: parent.width - Style.space(90)
              placeholderText: "Search 42+ countries (e.g. Korea, Japan, Iceland)..."
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

            Button {
              width: Style.space(84)
              height: searchInput.height
              text: root.showingSearchList ? "HIDE LIST" : "ALL (" + root.countryList.length + ")"
              bordered: true
              onClicked: root.showingSearchList = !root.showingSearchList
            }
          }

          // Search Dropdown List (if active)
          Rectangle {
            visible: root.showingSearchList
            width: parent.width
            height: Math.min(Style.space(160), searchListCol.implicitHeight + Style.space(10))
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

          // 7 Flag Lines, Grouped Into 3 Severity Tiers
          Item {
            visible: !root.showingSearchList
            width: parent.width
            height: flagColumn.implicitHeight + Style.space(8)

            Flickable {
              id: flagFlickable
              anchors.fill: parent
              anchors.bottomMargin: Style.space(8)
              contentWidth: flagColumn.implicitWidth
              contentHeight: flagColumn.implicitHeight
              clip: true
              boundsBehavior: Flickable.StopAtBounds

              Column {
                id: flagColumn
                spacing: Style.space(6)

                Repeater {
                  model: root.severityTiers

                  Column {
                    id: tierBlock
                    readonly property var tier: modelData
                    spacing: Style.space(3)

                    // Tier header: severity dot, name, and TFR band
                    Row {
                      spacing: Style.space(5)

                      Text {
                        text: tierBlock.tier.dot + " " + tierBlock.tier.label
                        color: tierBlock.tier.color
                        font.family: Style.font.family
                        font.pixelSize: Style.font.caption
                        font.bold: true
                      }

                      Text {
                        text: "TFR " + tierBlock.tier.range
                        color: Color.muted
                        font.family: Style.font.family
                        font.pixelSize: Style.font.caption
                      }
                    }

                    Repeater {
                      model: root.chunkLines(tierBlock.tier.countries, tierBlock.tier.lines)

                      Row {
                        id: flagLine
                        readonly property var lineCountries: modelData
                        spacing: Style.space(4)

                        Repeater {
                          model: flagLine.lineCountries

                          Button {
                            height: Style.space(21)
                            text: modelData.label
                            bordered: true
                            selected: modelData.code === root.selectedCountryCode
                            fontSize: 9.5
                            horizontalPadding: Style.space(5)
                            onClicked: root.selectCountry(modelData.code)
                          }
                        }
                      }
                    }
                  }
                }
              }
            }

            // Sleek Scroll Bar Track & Thumb -- only shown when a line overflows
            Rectangle {
              id: scrollTrack
              visible: flagFlickable.contentWidth > flagFlickable.width + 1
              anchors.bottom: parent.bottom
              anchors.left: parent.left
              anchors.right: parent.right
              height: 4
              radius: 2
              color: Qt.rgba(255, 255, 255, 0.08)

              Rectangle {
                id: scrollThumb
                height: parent.height
                radius: 2
                color: Color.accent

                readonly property real visibleRatio: Math.min(1.0, flagFlickable.width / Math.max(1, flagFlickable.contentWidth))
                width: Math.max(36, visibleRatio * scrollTrack.width)
                x: {
                  var maxContentX = Math.max(1, flagFlickable.contentWidth - flagFlickable.width)
                  var maxThumbX = scrollTrack.width - width
                  return Math.max(0, Math.min(maxThumbX, (flagFlickable.contentX / maxContentX) * maxThumbX))
                }
              }

              MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                onPositionChanged: function(mouse) {
                  if (pressed) {
                    var frac = Math.max(0, Math.min(1, mouse.x / width))
                    var maxContentX = Math.max(0, flagFlickable.contentWidth - flagFlickable.width)
                    flagFlickable.contentX = frac * maxContentX
                  }
                }
                onPressed: function(mouse) {
                  var frac = Math.max(0, Math.min(1, mouse.x / width))
                  var maxContentX = Math.max(0, flagFlickable.contentWidth - flagFlickable.width)
                  flagFlickable.contentX = frac * maxContentX
                }
              }
            }
          }
        }

        // 3. Country Vital Statistics Card
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
                  text: "2026 POPULATION"
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
                  color: root.currentCountry && root.currentCountry.peakYear <= 2026 ? "#f87171" : "#38bdf8"
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

        // 4. Vertical Age-Sex Population Pyramid
        PopulationPyramid {
          width: parent.width
          countryData: root.currentCountry
          selectedYear: root.selectedYear
        }

        // 5. Continuous Line Chart
        PopulationTrajectoryChart {
          width: parent.width
          countryData: root.currentCountry
          selectedYear: root.selectedYear
          onYearSelected: function(yr) {
            var yrNum = parseInt(yr, 10)
            var closest = "2026"
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

        // 6. Footer navigation instructions
        Text {
          anchors.horizontalCenter: parent.horizontalCenter
          text: "[Space] Play/Pause Animation  ·  [Hover Line Chart] Scrub Years  ·  [Esc] Dismiss"
          color: Color.muted
          font.family: Style.font.family
          font.pixelSize: 9
        }
      }
    }
  }
}
