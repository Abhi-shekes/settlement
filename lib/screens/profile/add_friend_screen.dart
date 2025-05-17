import 'package:flutter/material.dart';
import 'package:expense_tracker/services/friend_service.dart';
import 'package:expense_tracker/models/user_profile.dart';

class AddFriendScreen extends StatefulWidget {
  @override
  _AddFriendScreenState createState() => _AddFriendScreenState();
}

class _AddFriendScreenState extends State<AddFriendScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final FriendService _friendService = FriendService();

  bool _isLoading = false;
  List<UserProfile> _searchResults = [];
  bool _hasSearched = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _searchFriends() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
        _hasSearched = true;
      });

      try {
        final results = await _friendService.searchUsersByEmail(
          _emailController.text.trim(),
        );
        setState(() {
          _searchResults = results;
        });
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error searching for users: $e')),
        );
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _addFriend(UserProfile user) async {
    setState(() {
      _isLoading = true;
    });

    try {
      await _friendService.addFriend(user.id);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('${user.name} added as a friend')));
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error adding friend: $e')));
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Add Friend')),
      body:
          _isLoading
              ? Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          TextFormField(
                            controller: _emailController,
                            decoration: InputDecoration(
                              labelText: 'Search by Email',
                              prefixIcon: Icon(Icons.email),
                              suffixIcon: IconButton(
                                icon: Icon(Icons.search),
                                onPressed: _searchFriends,
                              ),
                            ),
                            keyboardType: TextInputType.emailAddress,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter an email';
                              }
                              if (!value.contains('@')) {
                                return 'Please enter a valid email';
                              }
                              return null;
                            },
                            onFieldSubmitted: (_) => _searchFriends(),
                          ),
                          SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: _searchFriends,
                            icon: Icon(Icons.search),
                            label: Text('Search'),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 24),
                    if (_hasSearched) ...[
                      Text(
                        'Search Results',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 8),
                      _searchResults.isEmpty
                          ? Card(
                            child: Padding(
                              padding: EdgeInsets.all(16),
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.search_off,
                                    size: 48,
                                    color: Colors.grey[400],
                                  ),
                                  SizedBox(height: 16),
                                  Text(
                                    'No users found with that email',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                          : ListView.builder(
                            shrinkWrap: true,
                            physics: NeverScrollableScrollPhysics(),
                            itemCount: _searchResults.length,
                            itemBuilder: (context, index) {
                              final user = _searchResults[index];
                              return Card(
                                margin: EdgeInsets.only(bottom: 8),
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Row(
                                    children: [
                                      CircleAvatar(
                                        backgroundColor: Colors.grey[300],
                                        child: Text(
                                          user.name
                                              .substring(0, 1)
                                              .toUpperCase(),
                                          style: TextStyle(
                                            color: Colors.black,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              user.name,
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            Text(
                                              user.email,
                                              style: TextStyle(
                                                color: Colors.grey[700],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      SizedBox(
                                        width: 80, // Set a fixed width
                                        height:
                                            36, // Optional: for consistent button height
                                        child: ElevatedButton(
                                          onPressed: () => _addFriend(user),
                                          child: Text('Add'),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                    ],
                  ],
                ),
              ),
    );
  }
}
