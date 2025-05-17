import 'package:flutter/material.dart';
import 'package:expense_tracker/services/group_service.dart';
import 'package:expense_tracker/services/friend_service.dart';
import 'package:expense_tracker/models/user_profile.dart';

class CreateGroupScreen extends StatefulWidget {
  @override
  _CreateGroupScreenState createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends State<CreateGroupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final GroupService _groupService = GroupService();
  final FriendService _friendService = FriendService();
  
  bool _isLoading = false;
  List<UserProfile> _friends = [];
  List<UserProfile> _selectedFriends = [];

  @override
  void initState() {
    super.initState();
    _loadFriends();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _loadFriends() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final friends = await _friendService.getFriends();
      setState(() {
        _friends = friends;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading friends: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _toggleFriendSelection(UserProfile friend) {
    setState(() {
      if (_selectedFriends.contains(friend)) {
        _selectedFriends.remove(friend);
      } else {
        _selectedFriends.add(friend);
      }
    });
  }

  Future<void> _createGroup() async {
    if (_formKey.currentState!.validate()) {
      if (_selectedFriends.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Please select at least one friend')),
        );
        return;
      }

      setState(() {
        _isLoading = true;
      });

      try {
        final memberIds = _selectedFriends.map((friend) => friend.id).toList();
        await _groupService.createGroup(_nameController.text, memberIds);
        Navigator.pop(context);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error creating group: $e')),
        );
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Create Group'),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFormField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        labelText: 'Group Name',
                        prefixIcon: Icon(Icons.group),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter a group name';
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: 24),
                    Text(
                      'Select Friends',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8),
                    if (_friends.isEmpty)
                      Card(
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: Column(
                            children: [
                              Icon(
                                Icons.people,
                                size: 48,
                                color: Colors.grey[400],
                              ),
                              SizedBox(height: 16),
                              Text(
                                'No friends found',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey[600],
                                ),
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Add friends to create a group with them',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      ListView.builder(
                        shrinkWrap: true,
                        physics: NeverScrollableScrollPhysics(),
                        itemCount: _friends.length,
                        itemBuilder: (context, index) {
                          final friend = _friends[index];
                          final isSelected = _selectedFriends.contains(friend);
                          
                          return Card(
                            margin: EdgeInsets.only(bottom: 8),
                            color: isSelected
                                ? Theme.of(context).primaryColor.withOpacity(0.1)
                                : null,
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: isSelected
                                    ? Theme.of(context).primaryColor
                                    : Colors.grey[300],
                                child: Text(
                                  friend.name.substring(0, 1).toUpperCase(),
                                  style: TextStyle(
                                    color: isSelected ? Colors.white : Colors.black,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              title: Text(friend.name),
                              subtitle: Text(friend.email),
                              trailing: Checkbox(
                                value: isSelected,
                                onChanged: (value) {
                                  _toggleFriendSelection(friend);
                                },
                                activeColor: Theme.of(context).primaryColor,
                              ),
                              onTap: () {
                                _toggleFriendSelection(friend);
                              },
                            ),
                          );
                        },
                      ),
                    SizedBox(height: 32),
                    ElevatedButton(
                      onPressed: _createGroup,
                      child: Text('Create Group'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
