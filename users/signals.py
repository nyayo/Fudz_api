# users/signals.py
from django.contrib.auth.models import Group, Permission
from django.db.models.signals import post_migrate
from django.dispatch import receiver
from django.apps import apps

@receiver(post_migrate)
def create_default_groups(sender, **kwargs):
    if sender.name == 'users':
        groups_permissions = {
            "manager": [
                "add_menuitem", "change_menuitem", "delete_menuitem",
                "add_menucategory", "change_menucategory", "delete_menucategory",
                "view_order",
            ],
            "waiter": ["view_order", "change_orderstatus"],
            "cashier": ["view_order", "change_orderstatus"],
        }

        for group_name, perms in groups_permissions.items():
            group, created = Group.objects.get_or_create(name=group_name)
            for perm_codename in perms:
                try:
                    perm = Permission.objects.get(codename=perm_codename)
                    group.permissions.add(perm)
                except Permission.DoesNotExist:
                    print(f"Permission {perm_codename} not found.")
