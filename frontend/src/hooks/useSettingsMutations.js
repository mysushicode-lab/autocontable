import { useMutation, useQueryClient } from 'react-query';
import { updateSetting, createUser, deleteUser, updateUser as apiUpdateUser, uploadProfilePhoto, deleteAccount, changePassword, changeUsername, changeEmail } from '../api';
import { useAuth } from '../context/AuthContext';

export const useSettingsMutations = () => {
  const queryClient = useQueryClient();
  const { user, updateUserPhoto } = useAuth();

  const updateMutation = useMutation(
    ({ key, value }) => updateSetting(key, value),
    {
      onSuccess: () => {
        queryClient.invalidateQueries('settings');
      },
    }
  );

  const photoMutation = useMutation(
    ({ userId, file }) => uploadProfilePhoto(userId, file),
    {
      onSuccess: (data) => {
        updateUserPhoto(data.photo_url);
      },
    }
  );

  const changePasswordMutation = useMutation(
    ({ current, new: newPass }) => changePassword(current, newPass)
  );

  const changeUsernameMutation = useMutation(
    (newUsername) => changeUsername(newUsername)
  );

  const changeEmailMutation = useMutation(
    (newEmail) => changeEmail(newEmail)
  );

  const createUserMutation = useMutation(createUser, {
    onSuccess: () => {
      queryClient.invalidateQueries('users');
    },
  });

  const deleteUserMutation = useMutation(deleteUser, {
    onSuccess: () => {
      queryClient.invalidateQueries('users');
    },
  });

  const updateUserMutation = useMutation(
    ({ userId, data }) => apiUpdateUser(userId, data),
    {
      onSuccess: (data, variables) => {
        queryClient.invalidateQueries('users');
        if (variables.userId === user?.id && data.user) {
          const updatedUser = { ...user, ...data.user };
          localStorage.setItem('auth_user', JSON.stringify(updatedUser));
          window.location.reload();
        }
      },
    }
  );

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
