import 'dart:collection';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';

part 'body.dart';

part 'indicators.dart';

part 'pane.dart';

part 'pane_items.dart';

part 'style.dart';

/// The default size used by the app top bar.
///
/// Value eyeballed from Windows 10 v10.0.19041.928
const double _kDefaultAppBarHeight = 50.0;

typedef NavigationContentBuilder = Widget Function(Widget? body);

/// The NavigationView control provides top-level navigation for your app. It
/// adapts to a variety of screen sizes and supports both top and left
/// navigation styles.
///
/// ![NavigationView Preview](https://docs.microsoft.com/en-us/windows/uwp/design/controls-and-patterns/images/nav-view-header.png)
///
/// See also:
///
///   * [NavigationPane], the pane used by [NavigationView], that can be
///     displayed either at the left and top
///   * [TabView], a widget similar to [NavigationView], useful to display
///     several pages of content while giving a user the capability to
///     rearrange, open, or close new tabs.
class NavigationView extends StatefulWidget {
  /// Creates a navigation view.
  const NavigationView({
    Key? key,
    this.appBar,
    this.pane,
    this.content,
    this.clipBehavior = Clip.antiAlias,
    this.contentShape,
    this.onOpenSearch,
    this.transitionBuilder,
    this.paneBodyBuilder,
  })  : assert(
          (pane != null && content == null) ||
              (pane == null && content != null),
          'Either pane or content must be provided',
        ),
        super(key: key);

  /// The app bar of the app.
  final NavigationAppBar? appBar;

  /// Can be used to override the widget that is built from
  /// the [PaneItem.body]. Only used if [pane] is provided.
  /// If nothing is selected, `body` will be null.
  ///
  /// This can be useful if you are using router-based navigation,
  /// and the body of the navigation pane is dynamically determined or
  /// affected by the current route rather than just by the currently
  /// selected pane.
  final NavigationContentBuilder? paneBodyBuilder;

  /// The navigation pane, that can be displayed either on the
  /// left, on the top, or above the body.
  final NavigationPane? pane;

  /// The content of the pane.
  ///
  /// If [pane] is provided, this is ignored
  ///
  /// Usually a [ScaffoldPage]
  final Widget? content;

  /// {@macro flutter.rendering.ClipRectLayer.clipBehavior}
  ///
  /// Defaults to [Clip.hardEdge].
  final Clip clipBehavior;

  /// How the body content should be clipped
  ///
  /// The body content is not clipped on when the display mode is [PaneDisplayMode.minimal]
  final ShapeBorder? contentShape;

  /// Called when the search button is tapped
  final VoidCallback? onOpenSearch;

  /// The transition builder.
  ///
  /// It can be detect the display mode of the parent [NavigationView], if any,
  /// and change the transition accordingly. By default, if the display mode is
  /// top, [HorizontalSlidePageTransition] is used, otherwise
  /// [EntrancePageTransition] is used.
  ///
  /// ```dart
  /// transitionBuilder: (child, animation) {
  ///   return DrillInPageTransition(child: child, animation: animation);
  /// },
  /// ```
  ///
  /// See also:
  ///
  ///  * [EntrancePageTransition], used by default
  ///  * [HorizontalSlidePageTransition], used by default on top navigation
  ///  * [DrillInPageTransition], used when users navigate deeper into an app
  ///  * [SuppressPageTransition], to have no animation at all
  ///  * <https://docs.microsoft.com/en-us/windows/apps/design/motion/page-transitions>
  final AnimatedSwitcherTransitionBuilder? transitionBuilder;

  static NavigationViewState of(BuildContext context) {
    return context.findAncestorStateOfType<NavigationViewState>()!;
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(DiagnosticsProperty('appBar', appBar))
      ..add(DiagnosticsProperty('pane', pane))
      ..add(DiagnosticsProperty(
        'clipBehavior',
        clipBehavior,
        defaultValue: Clip.hardEdge,
      ))
      ..add(DiagnosticsProperty('contentShape', contentShape));
  }

  @override
  NavigationViewState createState() => NavigationViewState();
}

class NavigationViewState extends State<NavigationView> {
  /// The scroll controller used to keep the scrolling state of
  /// the list view when the display mode is switched between open
  /// and compact, and even keep it for the minimal state.
  ///
  /// It's also used to display and control the [Scrollbar] introduced
  /// by the panes.
  late ScrollController paneScrollController;

  /// The key used to animate between open and compact display mode
  final _panelKey = GlobalKey();
  final _listKey = GlobalKey();
  final _contentKey = GlobalKey();
  final _overlayKey = GlobalKey();

  final Map<int, GlobalKey> _itemKeys = {};

  bool _minimalPaneOpen = false;

  /// Whether the minimal pane is open
  ///
  /// Always false if the current display mode is not minimal.
  bool get minimalPaneOpen => _minimalPaneOpen;
  set minimalPaneOpen(bool open) {
    if (displayMode == PaneDisplayMode.minimal) {
      setState(() => _minimalPaneOpen = open);
    } else {
      setState(() => _minimalPaneOpen = false);
    }
  }

  late bool _compactOverlayOpen;

  int _oldIndex = 0;

  PaneDisplayMode? _autoDisplayMode;

  /// Gets the current display mode. If it's automatic, it'll adapt to the other
  /// display modes according to the current available space.
  PaneDisplayMode get displayMode {
    if (widget.pane?.displayMode == PaneDisplayMode.auto) {
      return _autoDisplayMode ?? PaneDisplayMode.minimal;
    }

    return widget.pane?.displayMode ?? PaneDisplayMode.minimal;
  }

  @override
  void initState() {
    super.initState();
    paneScrollController = widget.pane?.scrollController ??
        ScrollController(
          debugLabel: '${widget.runtimeType} scroll controller',
          keepScrollOffset: true,
        );
    paneScrollController.addListener(_handleScrollControllerEvent);

    _generateKeys();

    _compactOverlayOpen = PageStorage.of(context)?.readState(
          context,
          identifier: 'compactOverlayOpen',
        ) as bool? ??
        false;
  }

  void _handleScrollControllerEvent() {
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(NavigationView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.pane?.scrollController != paneScrollController) {
      paneScrollController =
          widget.pane?.scrollController ?? paneScrollController;
    }

    if (oldWidget.pane?.selected != widget.pane?.selected) {
      _oldIndex = oldWidget.pane?.selected ?? -1;
    }

    if (oldWidget.pane?.effectiveItems.length !=
        widget.pane?.effectiveItems.length) {
      if (widget.pane?.effectiveItems.length != null) {
        _generateKeys();
      }
    }
  }

  void _generateKeys() {
    if (widget.pane == null) return;
    _itemKeys
      ..clear()
      ..addAll(
        Map.fromIterables(
          List.generate(widget.pane!.effectiveItems.length, (i) => i),
          List.generate(
            widget.pane!.effectiveItems.length,
            (_) => GlobalKey(),
          ),
        ),
      );
  }

  @override
  void dispose() {
    // If the controller was created locally, dispose it
    if (widget.pane?.scrollController == null) {
      paneScrollController.dispose();
    } else {
      paneScrollController.removeListener(_handleScrollControllerEvent);
    }
    super.dispose();
  }

  /// Toggles the current compact mode
  void toggleCompactOpenMode() {
    setState(() => _compactOverlayOpen = !_compactOverlayOpen);
    PageStorage.of(context)?.writeState(
      context,
      _compactOverlayOpen,
      identifier: 'compactOverlayOpen',
    );
  }

  @override
  Widget build(BuildContext context) {
    assert(debugCheckHasFluentTheme(context));
    assert(debugCheckHasFluentLocalizations(context));
    assert(debugCheckHasMediaQuery(context));
    assert(debugCheckHasDirectionality(context));

    final Brightness brightness = FluentTheme.of(context).brightness;
    final NavigationPaneThemeData theme = NavigationPaneTheme.of(context);
    final FluentLocalizations localizations = FluentLocalizations.of(context);
    final MediaQueryData mediaQuery = MediaQuery.of(context);
    final EdgeInsetsGeometry appBarPadding = EdgeInsetsDirectional.only(
      top: widget.appBar?.finalHeight(context) ?? 0.0,
    );
    final TextDirection direction = Directionality.of(context);

    Color? overlayBackgroundColor() {
      if (theme.backgroundColor == null) {
        if (brightness.isDark) {
          return const Color(0xFF202020);
        } else {
          return const Color(0xFFf7f7f7);
        }
      }
      return theme.backgroundColor;
    }

    Widget? paneNavigationButton() {
      final minimalLeading = PaneItem(
        title: Text(
          !minimalPaneOpen
              ? localizations.openNavigationTooltip
              : localizations.closeNavigationTooltip,
        ),
        icon: const Icon(FluentIcons.global_nav_button),
        body: const SizedBox.shrink(),
      ).build(
        context,
        false,
        () async {
          minimalPaneOpen = !minimalPaneOpen;
        },
        displayMode: PaneDisplayMode.compact,
      );
      return minimalLeading;
    }

    return LayoutBuilder(builder: (context, consts) {
      var displayMode = widget.pane?.displayMode ?? PaneDisplayMode.auto;

      if (displayMode == PaneDisplayMode.auto) {
        /// For more info on the adaptive behavior, see
        /// https://docs.microsoft.com/en-us/windows/apps/design/controls/navigationview#adaptive-behavior
        ///
        ///  DD/MM/YYYY
        /// (06/04/2022)
        ///
        /// When PaneDisplayMode is set to its default value of Auto, the
        /// adaptive behavior is to show:
        /// - An expanded left pane on large window widths (1008px or greater).
        /// - A left, icon-only, nav pane (compact) on medium window widths
        /// (641px to 1007px).
        /// - Only a menu button (minimal) on small window widths (640px or less).
        double width = consts.biggest.width;
        if (width.isInfinite) width = mediaQuery.size.width;

        if (width <= 640) {
          _autoDisplayMode = PaneDisplayMode.minimal;
        } else if (width >= 1008) {
          _autoDisplayMode = PaneDisplayMode.open;
        } else if (width > 640) {
          _autoDisplayMode = PaneDisplayMode.compact;
        }

        displayMode = _autoDisplayMode!;
      }
      assert(displayMode != PaneDisplayMode.auto);

      Widget appBar = () {
        if (widget.appBar != null) {
          return _NavigationAppBar(
            appBar: widget.appBar!,
            additionalLeading: () {
              if (widget.pane != null) {
                return displayMode == PaneDisplayMode.minimal
                    ? paneNavigationButton()
                    : null;
              }
            }(),
          );
        }
        return LayoutBuilder(
          builder: (context, constraints) => SizedBox(
            width: constraints.maxWidth,
            height: 0,
          ),
        );
      }();

      late Widget paneResult;
      if (widget.pane != null) {
        final pane = widget.pane!;
        final body = _NavigationBody(
          itemKey: ValueKey(pane.selected ?? -1),
          transitionBuilder: widget.transitionBuilder,
          paneBodyBuilder: widget.paneBodyBuilder,
        );

        if (pane.customPane != null) {
          paneResult = Builder(builder: (context) {
            return PaneScrollConfiguration(
              child: pane.customPane!.build(
                context,
                NavigationPaneWidgetData(
                  appBar: appBar,
                  content: ClipRect(child: body),
                  listKey: _listKey,
                  paneKey: _panelKey,
                  scrollController: paneScrollController,
                  pane: pane,
                ),
              ),
            );
          });
        } else {
          final contentShape = widget.contentShape ??
              RoundedRectangleBorder(
                side: BorderSide(
                  color:
                      FluentTheme.of(context).resources.cardStrokeColorDefault,
                ),
                borderRadius: displayMode == PaneDisplayMode.top
                    ? BorderRadius.zero
                    : const BorderRadiusDirectional.only(
                        topStart: Radius.circular(8.0),
                      ).resolve(direction),
              );
          final Widget content = ClipRect(
            key: _contentKey,
            child: displayMode == PaneDisplayMode.minimal
                ? body
                : DecoratedBox(
                    position: DecorationPosition.foreground,
                    decoration: ShapeDecoration(shape: contentShape),
                    child: ClipPath(
                      clipBehavior: widget.clipBehavior,
                      clipper: ShapeBorderClipper(shape: contentShape),
                      child: body,
                    ),
                  ),
          );
          if (displayMode != PaneDisplayMode.compact) {
            _compactOverlayOpen = false;
          }
          if (displayMode != PaneDisplayMode.open) {
            PageStorage.of(context)?.writeState(
              context,
              false,
              identifier: 'openModeOpen',
            );
          }
          switch (displayMode) {
            case PaneDisplayMode.top:
              paneResult = Column(children: [
                appBar,
                PaneScrollConfiguration(
                  child: _TopNavigationPane(
                    pane: pane,
                    listKey: _listKey,
                    appBar: widget.appBar,
                  ),
                ),
                Expanded(child: content),
              ]);
              break;
            case PaneDisplayMode.compact:

              // Ensure the overlay state is correct
              _compactOverlayOpen = PageStorage.of(context)?.readState(
                    context,
                    identifier: 'compactOverlayOpen',
                  ) as bool? ??
                  _compactOverlayOpen;

              double openSize =
                  pane.size?.openPaneWidth ?? kOpenNavigationPaneWidth;

              final bool noOverlayRequired = consts.maxWidth / 2.5 > openSize;
              final bool openedWithoutOverlay =
                  _compactOverlayOpen && consts.maxWidth / 2.5 > openSize;

              // print(
              //     'open: $_compactOverlayOpen - without overlay:$openedWithoutOverlay - storage: ${PageStorage.of(context)?.readState(
              //   context,
              //   identifier: 'compactOverlayOpen',
              // )}');

              if (noOverlayRequired) {
                paneResult = Column(children: [
                  appBar,
                  Expanded(
                    child: Row(children: [
                      PaneScrollConfiguration(
                        child: () {
                          if (openedWithoutOverlay) {
                            return Mica(
                              key: _overlayKey,
                              backgroundColor: theme.backgroundColor,
                              child: Container(
                                margin:
                                    const EdgeInsets.symmetric(vertical: 1.0),
                                child: _OpenNavigationPane(
                                  theme: theme,
                                  pane: pane,
                                  paneKey: _panelKey,
                                  listKey: _listKey,
                                  onToggle: toggleCompactOpenMode,
                                  initiallyOpen: true,
                                ),
                              ),
                            );
                          } else {
                            return KeyedSubtree(
                              key: _overlayKey,
                              child: _CompactNavigationPane(
                                pane: pane,
                                paneKey: _panelKey,
                                listKey: _listKey,
                                onToggle: toggleCompactOpenMode,
                                onOpenSearch: widget.onOpenSearch,
                              ),
                            );
                          }
                        }(),
                      ),
                      Expanded(child: content),
                    ]),
                  ),
                ]);
              } else {
                paneResult = Stack(children: [
                  Padding(
                    padding: EdgeInsetsDirectional.only(
                      top: appBarPadding.resolve(direction).top,
                      start: pane.size?.compactWidth ??
                          kCompactNavigationPaneWidth,
                    ),
                    child: content,
                  ),
                  // If the overlay is open, add a gesture detector above the
                  // content to close if the user click outside the overlay
                  if (_compactOverlayOpen && !openedWithoutOverlay)
                    Positioned.fill(
                      child: GestureDetector(
                        onTap: toggleCompactOpenMode,
                        child: AbsorbPointer(
                          child: Semantics(
                            label: localizations.modalBarrierDismissLabel,
                            child: const SizedBox.expand(),
                          ),
                        ),
                      ),
                    ),
                  PaneScrollConfiguration(
                    child: () {
                      if (_compactOverlayOpen) {
                        return ClipRect(
                          child: Mica(
                            key: _overlayKey,
                            backgroundColor: overlayBackgroundColor(),
                            elevation: 10.0,
                            child: Container(
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: const Color(0xFF6c6c6c),
                                  width: 0.15,
                                ),
                                borderRadius: BorderRadius.circular(8.0),
                              ),
                              margin: const EdgeInsets.symmetric(
                                vertical: 1.0,
                              ),
                              padding: appBarPadding,
                              child: _OpenNavigationPane(
                                theme: theme,
                                pane: pane,
                                paneKey: _panelKey,
                                listKey: _listKey,
                                onToggle: toggleCompactOpenMode,
                                onItemSelected: toggleCompactOpenMode,
                              ),
                            ),
                          ),
                        );
                      } else {
                        return Mica(
                          key: _overlayKey,
                          backgroundColor: overlayBackgroundColor(),
                          child: Padding(
                            padding: EdgeInsets.only(
                              top: appBarPadding.resolve(direction).top,
                            ),
                            child: _CompactNavigationPane(
                              pane: pane,
                              paneKey: _panelKey,
                              listKey: _listKey,
                              onToggle: toggleCompactOpenMode,
                              onOpenSearch: widget.onOpenSearch,
                            ),
                          ),
                        );
                      }
                    }(),
                  ),
                  appBar,
                ]);
              }
              break;
            case PaneDisplayMode.open:
              paneResult = Column(children: [
                appBar,
                Expanded(
                  child: Row(children: [
                    PaneScrollConfiguration(
                      child: _OpenNavigationPane(
                        theme: theme,
                        pane: pane,
                        paneKey: _panelKey,
                        listKey: _listKey,
                        initiallyOpen: PageStorage.of(context)?.readState(
                              context,
                              identifier: 'openModeOpen',
                            ) as bool? ??
                            false,
                      ),
                    ),
                    Expanded(child: content),
                  ]),
                ),
              ]);
              break;
            case PaneDisplayMode.minimal:
              paneResult = Stack(children: [
                Positioned(
                  top: widget.appBar?.finalHeight(context) ?? 0.0,
                  left: 0.0,
                  right: 0.0,
                  bottom: 0.0,
                  child: content,
                ),
                if (minimalPaneOpen)
                  Positioned.fill(
                    child: GestureDetector(
                      onTap: () => minimalPaneOpen = false,
                      child: AbsorbPointer(
                        child: Semantics(
                          label: localizations.modalBarrierDismissLabel,
                          child: const SizedBox.expand(),
                        ),
                      ),
                    ),
                  ),
                AnimatedPositionedDirectional(
                  key: _overlayKey,
                  duration: theme.animationDuration ?? Duration.zero,
                  curve: theme.animationCurve ?? Curves.linear,
                  start: minimalPaneOpen ? 0.0 : -kOpenNavigationPaneWidth,
                  width: kOpenNavigationPaneWidth,
                  height: mediaQuery.size.height,
                  child: PaneScrollConfiguration(
                    child: ColoredBox(
                      color: Colors.black,
                      child: Mica(
                        backgroundColor: overlayBackgroundColor(),
                        elevation: 0.0,
                        child: Container(
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: const Color(0xFF6c6c6c),
                              width: 0.15,
                            ),
                            borderRadius: BorderRadius.circular(8.0),
                          ),
                          margin: const EdgeInsets.symmetric(vertical: 1.0),
                          padding: appBarPadding,
                          child: _OpenNavigationPane(
                            theme: theme,
                            pane: pane,
                            paneKey: _panelKey,
                            listKey: _listKey,
                            onItemSelected: () => minimalPaneOpen = false,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                appBar,
              ]);
              break;
            default:
              paneResult = content;
          }
        }
      } else if (widget.content != null) {
        paneResult = Column(children: [
          appBar,
          Expanded(child: widget.content!),
        ]);
      } else {
        throw 'Either pane or content must be provided';
      }
      return Mica(
        backgroundColor: theme.backgroundColor,
        child: InheritedNavigationView(
          displayMode: _compactOverlayOpen ? PaneDisplayMode.open : displayMode,
          minimalPaneOpen: minimalPaneOpen,
          pane: widget.pane,
          oldIndex: _oldIndex,
          child: PaneItemKeys(keys: _itemKeys, child: paneResult),
        ),
      );
    });
  }

  // ignore: non_constant_identifier_names
  Widget PaneScrollConfiguration({required Widget child}) {
    return Builder(builder: (context) {
      return PrimaryScrollController(
        controller: paneScrollController,
        child: ScrollConfiguration(
          behavior: const NavigationViewScrollBehavior(),
          child: child,
        ),
      );
    });
  }
}

/// The bar displayed at the top of the app. It can adapt itself to
/// all the display modes.
///
/// See also:
///
///   * [NavigationView], which uses this to render the app bar
class NavigationAppBar with Diagnosticable {
  final Key? key;

  /// The widget at the beggining of the app bar, before [title].
  ///
  /// Typically the [leading] widget is an [Icon] or an [IconButton].
  ///
  /// If this is null and [automaticallyImplyLeading] is set to true, the
  /// view will imply an appropriate widget. If  the parent [Navigator] can
  /// go back, the app bar will use an [IconButton] that calls [Navigator.maybePop].
  ///
  /// See also:
  ///   * [automaticallyImplyLeading], that controls whether we should try to
  ///     imply the leading widget, if [leading] is null
  final Widget? leading;

  /// {@macro flutter.material.appbar.automaticallyImplyLeading}
  final bool automaticallyImplyLeading;

  /// Typically a [Text] widget that contains the app name.
  final Widget? title;

  /// A list of Widgets to display in a row after the [title] widget.
  ///
  /// Typically these widgets are [IconButton]s representing common
  /// operations.
  final Widget? actions;

  /// The height of the app bar. [_kDefaultAppBarHeight] is used by default
  final double height;

  /// The background color of this app bar.
  final Color? backgroundColor;

  /// Creates a fluent-styled app bar.
  const NavigationAppBar({
    this.key,
    this.leading,
    this.title,
    this.actions,
    this.automaticallyImplyLeading = true,
    this.height = _kDefaultAppBarHeight,
    this.backgroundColor,
  });

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(FlagProperty(
        'automatically imply leading',
        value: automaticallyImplyLeading,
        ifFalse: 'do not imply leading',
        defaultValue: true,
      ))
      ..add(ColorProperty('backgroundColor', backgroundColor))
      ..add(DoubleProperty(
        'height',
        height,
        defaultValue: _kDefaultAppBarHeight,
      ));
  }

  Widget _buildLeading([bool imply = true]) {
    return Builder(builder: (context) {
      late Widget widget;
      if (leading != null) {
        widget = leading!;
      } else if (automaticallyImplyLeading && imply) {
        final ModalRoute<dynamic>? parentRoute = ModalRoute.of(context);
        final bool canPop = parentRoute?.canPop ?? false;

        assert(debugCheckHasFluentLocalizations(context));
        assert(debugCheckHasFluentTheme(context));
        final localizations = FluentLocalizations.of(context);
        final onPressed = canPop ? () => Navigator.maybePop(context) : null;
        widget = NavigationPaneTheme(
          data: NavigationPaneTheme.of(context).merge(NavigationPaneThemeData(
            unselectedIconColor: ButtonState.resolveWith((states) {
              if (states.isDisabled) {
                return ButtonThemeData.buttonColor(context, states);
              }
              return ButtonThemeData.uncheckedInputColor(
                FluentTheme.of(context),
                states,
              ).basedOnLuminance();
            }),
          )),
          child: Builder(
            builder: (context) => PaneItem(
              icon: const Icon(FluentIcons.back, size: 14.0),
              title: Text(localizations.backButtonTooltip),
              body: const SizedBox.shrink(),
            ).build(
              context,
              false,
              onPressed,
              displayMode: PaneDisplayMode.compact,
            ),
          ),
        );
      } else {
        return const SizedBox.shrink();
      }
      widget = SizedBox(width: kCompactNavigationPaneWidth, child: widget);
      return widget;
    });
  }

  double finalHeight(BuildContext context) {
    assert(debugCheckHasMediaQuery(context));
    final mediaQuery = MediaQuery.of(context);
    final topPadding = mediaQuery.viewPadding.top;

    return height + topPadding;
  }
}

class _NavigationAppBar extends StatelessWidget {
  const _NavigationAppBar({
    Key? key,
    required this.appBar,
    required this.additionalLeading,
  }) : super(key: key);

  final NavigationAppBar appBar;
  final Widget? additionalLeading;

  @override
  Widget build(BuildContext context) {
    assert(debugCheckHasMediaQuery(context));
    assert(debugCheckHasFluentLocalizations(context));
    assert(debugCheckHasDirectionality(context));

    final mediaQuery = MediaQuery.of(context);
    final direction = Directionality.of(context);

    final PaneDisplayMode displayMode =
        InheritedNavigationView.maybeOf(context)?.displayMode ??
            PaneDisplayMode.top;
    final leading = appBar._buildLeading(displayMode != PaneDisplayMode.top);
    final title = () {
      if (appBar.title != null) {
        assert(debugCheckHasFluentTheme(context));
        final theme = NavigationPaneTheme.of(context);

        return AnimatedPadding(
          duration: theme.animationDuration ?? Duration.zero,
          curve: theme.animationCurve ?? Curves.linear,
          padding: (theme.iconPadding ?? EdgeInsets.zero).add(
            const EdgeInsetsDirectional.only(start: 6.0),
          ),
          child: DefaultTextStyle(
            style:
                FluentTheme.of(context).typography.caption ?? const TextStyle(),
            overflow: TextOverflow.clip,
            maxLines: 1,
            softWrap: false,
            child: appBar.title!,
          ),
        );
      } else {
        return const SizedBox.shrink();
      }
    }();
    late Widget result;
    switch (displayMode) {
      case PaneDisplayMode.top:
        result = Row(children: [
          leading,
          if (additionalLeading != null) additionalLeading!,
          title,
          if (appBar.actions != null) Expanded(child: appBar.actions!)
        ]);
        break;
      case PaneDisplayMode.minimal:
      case PaneDisplayMode.open:
      case PaneDisplayMode.compact:
        result = Stack(children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              leading,
              if (additionalLeading != null) additionalLeading!,
              Flexible(child: title),
            ]),
          ),
          if (appBar.actions != null)
            Positioned.directional(
              textDirection: direction,
              start: 0,
              end: 0.0,
              top: 0.0,
              bottom: 0.0,
              child: Align(
                alignment: Alignment.topRight,
                child: appBar.actions!,
              ),
            ),
        ]);
        break;
      default:
        return const SizedBox.shrink();
    }
    final topPadding = mediaQuery.viewPadding.top;

    return Container(
      color: appBar.backgroundColor,
      height: appBar.finalHeight(context),
      padding: EdgeInsets.only(top: topPadding),
      child: result,
    );
  }
}

/// The [ScrollBehavior] used on [NavigationView]
///
/// It generates a [Scrollbar] using the global scroll controller provided by
/// [NavigationView]
class NavigationViewScrollBehavior extends FluentScrollBehavior {
  const NavigationViewScrollBehavior();

  @override
  Widget buildScrollbar(context, child, details) {
    return Scrollbar(
      controller: details.controller,
      thumbVisibility: false,
      interactive: true,
      child: child,
    );
  }
}
