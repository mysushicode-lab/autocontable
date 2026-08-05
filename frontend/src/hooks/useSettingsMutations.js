import { useMutation, useQueryClient } from '@tanstack/react-query';
import { updateSetting, createUser, deleteUser, updateUser as apiUpdateUser, uploadProfilePhoto, deleteAccount, changePassword, changeUsername, changeEmail } from '../api';
import { useAuth } from '../context/AuthContext';

export const useSettingsMutations = () => {
  const queryClient = useQueryClient();
  const { user, updateUserPhoto } = useAuth();

  const updateMutation = useMutation({
    mutationFn: ({ key, value }) => updateSetting(key, value),
    onSuccess: () => {
      queryClient.invalidateQueries('settings');
    },
  });

  const photoMutation = useMutation({
    mutationFn: ({ userId, file }) => uploadProfilePhoto(userId, file),
    onSuccess: (data) => {
      updateUserPhoto(data.photo_url);
    },
  });

  const changePasswordMutation = useMutation({
    mutationFn: ({ current, new: newPass }) => changePassword(current, newPass)
  });

  const changeUsernameMutation = useMutation({
    mutationFn: (newUsername) => changeUsername(newUsername)
  });

  const changeEmailMutation = useMutation({
    mutationFn: (newEmail) => changeEmail(newEmail)
  });

  const createUserMutation = useMutation({
    mutationFn: createUser,
    onSuccess: () => {
      queryClient.invalidateQueries('users');
    },
  });

  const deleteUserMutation = useMutation({
    mutationFn: deleteUser,
    onSuccess: () => {
      queryClient.invalidateQueries('users');
    },
  });

  const updateUserMutation = useMutation({
    mutationFn: ({ userId, data }) => apiUpdateUser(userId, data),
    onSuccess: (data, variables) => {
      queryClient.invalidateQueries('users');
      if (variables.userId === user?.id && data.user) {
        const updatedUser = { ...user, ...data.user };
        localStorage.setItem('auth_user', JSON.stringify(updatedUser));
        window.location.reload();
      }
    },
  });

  return {
    updateMutation,
    photoMutation,
    changePasswordMutation,
    changeUsernameMutation,
    changeEmailMutation,
    createUserMutation,
    deleteUserMutation,
    updateUserMutation,
  };
};
