import 'package:material_ui/material_ui.dart';

import 'pages/buttons_page.dart';
import 'pages/disclosure_page.dart';
import 'pages/hex_viewer_page.dart';
import 'pages/inputs_page.dart';
import 'pages/progress_page.dart';
import 'pages/slots_page.dart';
import 'pages/status_page.dart';
import 'pages/surfaces_page.dart';

/// One demo page in the gallery.
final class GalleryEntry {
  const GalleryEntry({
    required this.path,
    required this.title,
    required this.builder,
  });

  final String path;
  final String title;
  final WidgetBuilder builder;
}

/// Every component gets a page. Adding a component means adding a row here.
const List<GalleryEntry> galleryEntries = <GalleryEntry>[
  GalleryEntry(path: '/buttons', title: 'Buttons', builder: buildButtonsPage),
  GalleryEntry(
    path: '/inputs',
    title: 'Inputs and overlays',
    builder: buildInputsPage,
  ),
  GalleryEntry(
    path: '/surfaces',
    title: 'Cards and lists',
    builder: buildSurfacesPage,
  ),
  GalleryEntry(
    path: '/status',
    title: 'Status chips',
    builder: buildStatusPage,
  ),
  GalleryEntry(
    path: '/progress',
    title: 'Progress and steps',
    builder: buildProgressPage,
  ),
  GalleryEntry(path: '/hex', title: 'Hex viewer', builder: buildHexViewerPage),
  GalleryEntry(path: '/slots', title: 'Slot tiles', builder: buildSlotsPage),
  GalleryEntry(
    path: '/disclosure',
    title: 'Disclosure',
    builder: buildDisclosurePage,
  ),
];
