import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/models/note.dart';

class LocalNoteDataSource {
  // Ключ, под которым мы будем хранить ВСЕ заметки в виде одной JSON-строки
  static const String _notesKey = 'all_pdf_notes';

  Future<void> saveNote(Note note) async {
    final prefs = await SharedPreferences.getInstance();
    final notes = await getNotes();
    
    // Удаляем старую версию этой заметки, если она есть
    notes.removeWhere((n) => n.id == note.id);
    // Добавляем новую
    notes.add(note);

    // Превращаем список объектов в список Map, затем в JSON-строку
    final List<Map<String, dynamic>> jsonList = notes.map((n) => n.toJson()).toList();
    final String jsonString = jsonEncode(jsonList); // <-- Ошибка №1 исправлена здесь
    
    await prefs.setString(_notesKey, jsonString);
  }

  Future<List<Note>> getNotes() async {
    final prefs = await SharedPreferences.getInstance();
    final String? jsonString = prefs.getString(_notesKey);
    
    if (jsonString == null) return [];

    try {
      // Декодируем строку в список динамических объектов
      final List<dynamic> decodedList = jsonDecode(jsonString);
      
      // Преобразуем каждый элемент в Map и затем в Note
      final List<Map<String, dynamic>> jsonList = 
          decodedList.map((e) => e as Map<String, dynamic>).toList(); // <-- Ошибка №2 исправлена здесь

      return jsonList.map((json) => Note.fromJson(json)).toList();
    } catch (e) {
      // Если данные повреждены, возвращаем пустой список
      return [];
    }
  }

  Future<void> deleteNote(String noteId) async {
    final prefs = await SharedPreferences.getInstance();
    final notes = await getNotes();
    
    notes.removeWhere((n) => n.id == noteId);
    
    final List<Map<String, dynamic>> jsonList = notes.map((n) => n.toJson()).toList();
    final String jsonString = jsonEncode(jsonList); // <-- Ошибка №3 исправлена здесь
    
    await prefs.setString(_notesKey, jsonString);
  }
}