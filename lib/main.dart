import 'package:flutter/material.dart';

/// Entrypoint of the application.
void main() {
  runApp(const MyApp());
}

/// [Widget] building the [MaterialApp].
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: Dock(
            items: const [
              Icons.person,
              Icons.message,
              Icons.call,
              Icons.camera,
              Icons.photo,
            ],
            descriptions: const [
              "Contacts",
              "Messages",
              "Phone",
              "Camera",
              "Gallery"
            ],
            builder: (e) {
              return Container(
                constraints: const BoxConstraints(minWidth: 48),
                height: 48,
                margin: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.primaries[e.hashCode % Colors.primaries.length],
                ),
                child: Center(child: Icon(e, color: Colors.white)),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Dock of the reorderable [items].
class Dock<T> extends StatefulWidget {
  const Dock({
    super.key,
    this.items = const [],
    this.descriptions = const [],
    required this.builder,
  });

  /// Initial [T] items to put in this [Dock].
  final List<T> items;

  final List<String> descriptions;

  /// Builder building the provided [T] item.
  final Widget Function(T) builder;

  @override
  State<Dock<T>> createState() => _DockState<T>();
}

/// State of the [Dock] used to manipulate the [_items].
class _DockState<T> extends State<Dock<T>> with TickerProviderStateMixin {
  /// [T] items being manipulated.
  late final List<T> _items = widget.items.toList();

  ///
  late final List<String> _descriptions = widget.descriptions.toList();

  /// The index of the item that is being animated to "make space" for the dragged item.
  int? _nextToIndex;

  /// The index of the item the user is currently hovering their cursor over.
  int? _hoveredIndex;

  /// The index of the item that is currently being dragged.
  int? _dragIndex;

  /// Offset between drag's starting and finishing position.
  Offset _dragOffset = Offset.zero;

  /// Whether the item being dragged is on the right side of the screen.
  bool _isPastHalf = false;

  /// Whether there is a dropped item currently returning to it's original position.
  bool _returned = true;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: Colors.black12,
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(_items.length, (index) {
          return MouseRegion(

              /// Sets [_hoveredIndex] to this item's index when cursor enters the [MouseRegion].
              ///
              /// If an item is currently being dragged, scaling animation is disabled for other items.
              onEnter: (details) {
                setState(() {
                  if (_nextToIndex == null) {}
                  _hoveredIndex = index;
                });
              },

              /// Clears [_hoveredIndex] upon cursor leaving this item.
              onExit: (details) {
                setState(() {});
                _hoveredIndex = null;
              },
              child: Transform.translate(
                /// This offset allows for a dropped item to smoothly return to it's original place.
                ///
                /// If this item was being dragged recently and was dropped outside of a valid [DragTarget],
                /// this offset is set to be the same as the offset created by the entire drag action.
                offset: (_dragIndex == index && !_returned)
                    ? _dragOffset
                    : Offset.zero,
                child: AnimatedContainer(
                  /// Duration of the item's return animation.
                  ///
                  /// Since [AnimatedContainer] animates both transitions (in this case [_returned] switching to true and then to false)
                  /// and one of the translations made to this item's position is already handled by it's parent [Transform.translate]
                  /// setting the animation duration to zero allows to skip the undesired transition.
                  duration: _returned
                      ? Duration.zero
                      : const Duration(milliseconds: 300),

                  /// Transformation made during the item's return animation.
                  ///
                  /// After being dropped outside of a valid [DragTarget] the item's return to it's original place in the dock is animated
                  /// by inverting the offset created by the drag action.
                  transform: (_dragIndex == index && !_returned)
                      ? (Matrix4.identity()
                        ..translate(-_dragOffset.dx, -_dragOffset.dy))
                      : Matrix4.identity(),

                  /// Clears values used when animating an item returning to the dock.
                  onEnd: () {
                    _dragOffset = Offset.zero;
                    _dragIndex = null;
                    _returned = true;
                  },
                  child: AnimatedContainer(
                    /// Transformation made when the user hovers over an item.
                    ///
                    /// The item gets scaled and it's position is translated to keep it's center in the same place as before.
                    transform: (_hoveredIndex == index && _nextToIndex == null)
                        ? (Matrix4.identity()
                          ..translate(-.15 * 64, -.15 * 64)
                          ..scale(1.3, 1.3))
                        : Matrix4.identity(),
                    duration: const Duration(milliseconds: 300),
                    child: Draggable<int>(
                      data: index,

                      /// Sets [_dragIndex] to this item's index.
                      onDragStarted: () {
                        setState(() {
                          _dragIndex = index;
                        });
                      },
                      onDragEnd: (_) {},

                      /// Show a fully scaled item when dragging said item.
                      feedback: Transform.scale(
                        scale: 1.3,
                        child: widget.builder(_items[index]),
                      ),

                      /// Visually remove the item from the dock afer drag starts.
                      childWhenDragging: const SizedBox.shrink(),

                      /// Clears [_dragOffset]
                      onDragCompleted: () {
                        setState(() {
                          _dragOffset = Offset.zero;
                          _dragIndex = null;
                        });
                      },

                      /// Keeps track of the offset created by the drag action.
                      ///
                      /// Since [onDragStarted] doesn't provide [DraggableDetails] or anything similar, there is
                      /// no information about the global offset of the item when the drag starts. To circumvent this,
                      /// every update's offset is added together to determine the entire offset.
                      onDragUpdate: (details) {
                        _dragOffset += details.delta;
                      },

                      /// Starts the animation for the item's return if it's dropped outside of the dock.
                      onDraggableCanceled: (_, __) {
                        setState(() {
                          _returned = false;
                        });
                      },
                      child: DragTarget<int>(
                        /// Reorders items in the list based on where in the dock they've been dropped.
                        ///
                        /// If the item is dropped in a different spot on the dock, it's new position is depended on two factors.
                        /// On the left side of the screen items move to the right to accomodate the item that the user is dragging.
                        /// In that case the hovering item should be inserted at the index of the item that it's hovering over.
                        /// However, on the right side of the screen items move to the left, so the insertion should occur at
                        /// the index of the item to the left of the item that is being hovered over.
                        /// Additionally, if the item is moved to the right, to account for indexes being lowered after removing
                        /// the dragged item from the list those indexes should be increased by one.
                        onAcceptWithDetails: (details) {
                          setState(() {
                            final oldIndex = details.data;
                            final newIndex = index > oldIndex
                                ? _isPastHalf
                                    ? index
                                    : index - 1
                                : _isPastHalf
                                    ? index + 1
                                    : index;
                            if (oldIndex != index) {
                              final item = _items.removeAt(oldIndex);
                              _items.insert(newIndex, item);
                              final desc = _descriptions.removeAt(oldIndex);
                              _descriptions.insert(newIndex, desc);
                            }
                            _nextToIndex = null;
                          });
                        },

                        /// Flags this item as the one that's currently being hovered over when dragging an item around.
                        onWillAcceptWithDetails: (details) {
                          setState(() {
                            _nextToIndex = index;
                          });
                          return true;
                        },

                        /// Checks if the item being dragges is on the left or right side of the screen.
                        ///
                        /// Determines if items should slide right or left.
                        /// This is done to allow items to be dropped anywhere on the dock.
                        /// Without it, either the left of the first item or the right of the last
                        /// would be unaccessible.
                        onMove: (details) {
                          var screenWidth = MediaQuery.of(context).size.width;
                          if (details.offset.dx > screenWidth ~/ 2) {
                            setState(() {
                              _isPastHalf = true;
                            });
                          } else {
                            setState(() {
                              _isPastHalf = false;
                            });
                          }
                        },
                        onLeave: (_) {
                          setState(() {
                            _nextToIndex = null;
                          });
                        },
                        builder: (context, candidateData, rejectedData) {
                          final isHovering = _nextToIndex == index;
                          final double gapPadding = isHovering ? 32.0 : 0.0;
                          return AnimatedPadding(
                            /// Animates items moving over to make space for the dragged item.
                            ///
                            /// If the dragged item is on the left side of the screen, items "move" to the right by
                            /// creating a padding on their left side. The inverse happens on the right side of the screen.
                            padding: _isPastHalf
                                ? EdgeInsets.only(right: gapPadding)
                                : EdgeInsets.only(left: gapPadding),

                            /// Similarly to the item's return animation, the "return" half of the animation is unnecessary thus skipped.
                            duration: isHovering
                                ? const Duration(milliseconds: 200)
                                : Duration.zero,
                            child: Tooltip(

                                /// Shows information about the item when hovered over.
                                message: _descriptions[index].toString(),
                                child: widget.builder(_items[index])),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ));
        }),
      ),
    );
  }
}
