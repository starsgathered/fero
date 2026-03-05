class MessageDto {
  final String text;
  final String userId;

  MessageDto({required this.text, required this.userId});

  Map<String, dynamic> toJson() => {
        'text': text,
        'userId': userId,
      };

  factory MessageDto.fromJson(Map<String, dynamic> json) => MessageDto(
        text: json['text'],
        userId: json['userId'],
      );
}
