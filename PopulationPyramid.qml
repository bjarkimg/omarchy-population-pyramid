import QtQuick
import qs.Commons
import qs.Ui

Item {
  id: root

  property var countryData: null
  property string selectedYear: "2026"
  property color maleColor: "#38bdf8"      // Cyan/Sky Blue
  property color femaleColor: "#f472b6"    // Soft Rose/Pink
  property color maleBg: Qt.rgba(0.22, 0.74, 0.97, 0.15)
  property color femaleBg: Qt.rgba(0.96, 0.45, 0.71, 0.15)
  property color activeRowBg: Qt.rgba(1, 1, 1, 0.07)
  property int hoveredIndex: -1

  readonly property var ageGroups: [
    "0-4", "5-9", "10-14", "15-19", "20-24", "25-29", "30-34", "35-39",
    "40-44", "45-49", "50-54", "55-59", "60-64", "65-69", "70-74", "75-79",
    "80-84", "85-89", "90-94", "95-99", "100+"
  ]

  // Retrieve current pyramid data for the selected year
  readonly property var yearPyramid: (countryData && countryData.pyramids && countryData.pyramids[selectedYear]) 
    ? countryData.pyramids[selectedYear] 
    : (countryData && countryData.pyramids ? countryData.pyramids["2026"] : null)

  readonly property var maleData: yearPyramid ? yearPyramid.m : []
  readonly property var femaleData: yearPyramid ? yearPyramid.f : []

  // Compute maximum cohort percentage across this pyramid to scale bar widths
  readonly property real maxCohortPct: {
    var maxVal = 6.0
    if (maleData) {
      for (var i = 0; i < maleData.length; i++) {
        if (maleData[i] > maxVal) maxVal = maleData[i]
      }
    }
    if (femaleData) {
      for (var j = 0; j < femaleData.length; j++) {
        if (femaleData[j] > maxVal) maxVal = femaleData[j]
      }
    }
    return Math.max(maxVal * 1.08, 7.0)
  }

  // Population volume scaling factor relative to peak / 2026
  readonly property real volumeScale: {
    if (yearPyramid && yearPyramid.popRatio !== undefined) {
      return Math.max(0.015, Math.min(1.0, yearPyramid.popRatio))
    }
    return 1.0
  }

  implicitWidth: Style.space(460)
  implicitHeight: pyramidColumn.implicitHeight + Style.space(32)

  Column {
    id: pyramidColumn
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: parent.top
    spacing: 1

    // Header Row
    Row {
      width: parent.width
      height: Style.space(20)

      Item {
        width: (parent.width - Style.space(110)) / 2
        height: parent.height
        Text {
          anchors.right: parent.right
          anchors.rightMargin: Style.space(6)
          anchors.verticalCenter: parent.verticalCenter
          text: "◀ MALES"
          color: root.maleColor
          font.family: Style.font.family
          font.pixelSize: Style.font.caption
          font.bold: true
        }
      }

      Item {
        width: Style.space(110)
        height: parent.height
        Text {
          anchors.centerIn: parent
          text: root.selectedYear + (root.yearPyramid && root.yearPyramid.pop !== undefined ? (" · " + (root.yearPyramid.pop >= 1000 ? (root.yearPyramid.pop/1000).toFixed(2) + "B" : root.yearPyramid.pop >= 1.0 ? root.yearPyramid.pop.toFixed(1) + "M" : (root.yearPyramid.pop*1000).toFixed(0) + "k")) : "")
          color: Color.foreground
          font.family: Style.font.family
          font.pixelSize: Style.font.caption
          font.bold: true
        }
      }

      Item {
        width: (parent.width - Style.space(110)) / 2
        height: parent.height
        Text {
          anchors.left: parent.left
          anchors.leftMargin: Style.space(6)
          anchors.verticalCenter: parent.verticalCenter
          text: "FEMALES ▶"
          color: root.femaleColor
          font.family: Style.font.family
          font.pixelSize: Style.font.caption
          font.bold: true
        }
      }
    }

    // 21 Age Bracket Rows (displayed top to bottom: 100+ down to 0-4)
    Repeater {
      model: 21

      Item {
        id: rowItem
        // Index 0 in display is cohort 20 (100+), Index 20 is cohort 0 (0-4)
        readonly property int cohortIndex: 20 - index
        readonly property real mVal: (root.maleData && root.maleData[cohortIndex] !== undefined) ? root.maleData[cohortIndex] : 0
        readonly property real fVal: (root.femaleData && root.femaleData[cohortIndex] !== undefined) ? root.femaleData[cohortIndex] : 0
        readonly property string ageLabel: root.ageGroups[cohortIndex] || ""
        readonly property bool isHovered: root.hoveredIndex === cohortIndex
        readonly property real sideWidth: (parent.width - Style.space(56)) / 2

        width: parent.width
        height: Style.space(13)

        Rectangle {
          anchors.fill: parent
          color: rowItem.isHovered ? root.activeRowBg : "transparent"
          radius: 2
        }

        MouseArea {
          anchors.fill: parent
          hoverEnabled: true
          onEntered: root.hoveredIndex = rowItem.cohortIndex
          onExited: if (root.hoveredIndex === rowItem.cohortIndex) root.hoveredIndex = -1
        }

        // Left Side: Male Bar (Right-aligned)
        Item {
          anchors.left: parent.left
          anchors.top: parent.top
          anchors.bottom: parent.bottom
          width: rowItem.sideWidth

          Text {
            anchors.left: parent.left
            anchors.leftMargin: Style.space(4)
            anchors.verticalCenter: parent.verticalCenter
            text: rowItem.mVal.toFixed(1) + "%"
            color: rowItem.isHovered ? root.maleColor : Color.muted
            font.family: Style.font.family
            font.pixelSize: 9
            visible: rowItem.isHovered || (index % 4 === 0)
          }

          // Background track (Ghost silhouette of peak width)
          Rectangle {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - Style.space(34)
            height: Style.space(8)
            radius: 2
            color: root.maleBg
          }

          // Active Male bar (scaled by population volume collapse)
          Rectangle {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: Math.max(1, (rowItem.mVal / root.maxCohortPct) * (parent.width - Style.space(34)) * root.volumeScale)
            height: Style.space(8)
            radius: 2
            color: rowItem.isHovered ? Qt.lighter(root.maleColor, 1.2) : root.maleColor

            Behavior on width {
              NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
            }
          }
        }

        // Center: Age Label
        Item {
          anchors.horizontalCenter: parent.horizontalCenter
          anchors.top: parent.top
          anchors.bottom: parent.bottom
          width: Style.space(56)

          Text {
            anchors.centerIn: parent
            text: rowItem.ageLabel
            color: rowItem.isHovered ? Color.foreground : (rowItem.cohortIndex >= 13 ? "#f59e0b" : Color.muted)
            font.family: Style.font.family
            font.pixelSize: 9
            font.bold: rowItem.isHovered || rowItem.cohortIndex === 0 || rowItem.cohortIndex === 13
          }
        }

        // Right Side: Female Bar (Left-aligned)
        Item {
          anchors.right: parent.right
          anchors.top: parent.top
          anchors.bottom: parent.bottom
          width: rowItem.sideWidth

          // Background track (Ghost silhouette of peak width)
          Rectangle {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - Style.space(34)
            height: Style.space(8)
            radius: 2
            color: root.femaleBg
          }

          // Active Female bar (scaled by population volume collapse)
          Rectangle {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: Math.max(1, (rowItem.fVal / root.maxCohortPct) * (parent.width - Style.space(34)) * root.volumeScale)
            height: Style.space(8)
            radius: 2
            color: rowItem.isHovered ? Qt.lighter(root.femaleColor, 1.2) : root.femaleColor

            Behavior on width {
              NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
            }
          }

          Text {
            anchors.right: parent.right
            anchors.rightMargin: Style.space(2)
            anchors.verticalCenter: parent.verticalCenter
            text: rowItem.fVal.toFixed(1) + "%"
            color: rowItem.isHovered ? root.femaleColor : Color.muted
            font.family: Style.font.family
            font.pixelSize: 9
            visible: rowItem.isHovered || (index % 4 === 0)
          }
        }
      }
    }

    // Hover Details Banner at Bottom of Pyramid
    Item {
      width: parent.width
      height: Style.space(20)

      Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.25)
        radius: 4
      }

      Text {
        anchors.centerIn: parent
        width: parent.width - Style.space(10)
        horizontalAlignment: Text.AlignHCenter
        elide: Text.ElideRight
        textFormat: Text.PlainText
        text: {
          if (root.hoveredIndex >= 0) {
            var m = (root.maleData && root.maleData[root.hoveredIndex] !== undefined) ? root.maleData[root.hoveredIndex] : 0
            var f = (root.femaleData && root.femaleData[root.hoveredIndex] !== undefined) ? root.femaleData[root.hoveredIndex] : 0
            var cohortName = root.ageGroups[root.hoveredIndex]
            var totalPct = (m + f).toFixed(1)
            var popMil = (root.yearPyramid && root.yearPyramid.pop !== undefined) ? root.yearPyramid.pop : (root.countryData ? root.countryData.population2026 : 0)
            var cohortPop = ((m + f) / 100.0) * popMil
            var popStr = cohortPop >= 1000 ? (cohortPop/1000).toFixed(2) + "B" : (cohortPop >= 1.0 ? cohortPop.toFixed(2) + "M" : (cohortPop * 1000).toFixed(0) + "k")
            return "Age " + cohortName + ": " + totalPct + "% (" + popStr + ") · M " + m.toFixed(1) + "% · F " + f.toFixed(1) + "%"
          }
          var yp = root.yearPyramid
          if (yp && yp.medianAgeGap !== undefined) {
            return "Median M " + yp.medianAgeM.toFixed(1) + " / F " + yp.medianAgeF.toFixed(1)
              + " (Δ" + yp.medianAgeGap.toFixed(1) + "y)  ·  Δe₀ " + yp.lifeExpGap.toFixed(1)
              + "y  ·  " + yp.sexRatio.toFixed(0) + " M/100F  ·  65+ " + yp.female65Share.toFixed(0) + "% F"
          }
          return "Hover any age bracket for breakdown  ·  Orange cohorts = 65+ Elderly"
        }
        color: root.hoveredIndex >= 0 ? Color.foreground : Color.muted
        font.family: Style.font.family
        font.pixelSize: 9
      }
    }
  }
}
