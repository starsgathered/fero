// import 'package:flutter/material.dart';
// import 'package:fero_sync/config/fero_config.dart';
// import 'package:fero_sync/socket/FeroSocket.dart';
// import 'package:fero_sync/socket/message-dto.dart';

// void main() {
//   WidgetsFlutterBinding.ensureInitialized();
//   runApp(const MyApp());
// }

// class MyApp extends StatelessWidget {
//   const MyApp({super.key});

//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       title: 'FeroSocket Test',
//       home: const SocketTestPage(),
//     );
//   }
// }

// class SocketTestPage extends StatefulWidget {
//   const SocketTestPage({super.key});

//   @override
//   State<SocketTestPage> createState() => _SocketTestPageState();
// }

// class _SocketTestPageState extends State<SocketTestPage> {
//   final List<MessageDto> _messages = [];
//   final TextEditingController _controller = TextEditingController();
//   late final FeroSocketService _feroSocket;

//   @override
//   void initState() {
//     super.initState();
//     _setupSocket();
//   }

//   void _setupSocket() {
//     // 1️⃣ Initialize config
//     final config = FeroConfig();
//     config.initialize(environment: Environment.dev);

//     // 2️⃣ Initialize socket service
//     _feroSocket = FeroSocketService();

//     // 3️⃣ Listen to incoming messages
//     _feroSocket.onMessageReceived = (msg) {
//       print("message received: ${msg.text} from ${msg.userId}");
//       setState(() {
//         _messages.add(msg);
//       });
//     };

//     // 4️⃣ Connect to socket
//     _feroSocket.connect(
//       host: config.socketHost,
//       port: config.socketPort,
//       useHttps: config.useHttps,
//     );
//   }

//   void _sendMessage() {
//     final text = _controller.text.trim();
//     if (text.isEmpty) return;

//     final msg = MessageDto(text: text, userId: 'mobile_tester');
//     _feroSocket.sendMessage(msg);

//     setState(() {
//       _messages.add(msg); // show own message instantly
//     });

//     _controller.clear();
//   }

//   @override
//   void dispose() {
//     _feroSocket.disconnect();
//     _controller.dispose();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(title: const Text('FeroSocket Test')),
//       body: Column(
//         children: [
//           Expanded(
//             child: ListView.builder(
//               reverse: true,
//               padding: const EdgeInsets.all(8),
//               itemCount: _messages.length,
//               itemBuilder: (context, index) {
//                 final msg = _messages[_messages.length - 1 - index];
//                 return Align(
//                   alignment: msg.userId == 'mobile_tester'
//                       ? Alignment.centerRight
//                       : Alignment.centerLeft,
//                   child: Container(
//                     margin: const EdgeInsets.symmetric(vertical: 4),
//                     padding: const EdgeInsets.all(10),
//                     decoration: BoxDecoration(
//                       color: msg.userId == 'mobile_tester'
//                           ? Colors.blue[200]
//                           : Colors.grey[300],
//                       borderRadius: BorderRadius.circular(8),
//                     ),
//                     child: Text('${msg.userId}: ${msg.text}'),
//                   ),
//                 );
//               },
//             ),
//           ),
//           Padding(
//             padding: const EdgeInsets.all(8.0),
//             child: Row(
//               children: [
//                 Expanded(
//                   child: TextField(
//                     controller: _controller,
//                     decoration:
//                         const InputDecoration(hintText: 'Enter message...'),
//                   ),
//                 ),
//                 IconButton(
//                   icon: const Icon(Icons.send),
//                   onPressed: _sendMessage,
//                 )
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }
