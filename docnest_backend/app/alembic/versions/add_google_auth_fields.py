"""add google auth fields

Revision ID: add_google_auth_fields
Revises: initial_migration
Create Date: 2024-02-08 10:00:00.000000

"""
from alembic import op
import sqlalchemy as sa

# revision identifiers, used by Alembic.
revision = 'add_google_auth_fields'
down_revision = 'initial_migration'
branch_labels = None
depends_on = None

def upgrade():
    # Make hashed_password nullable for Google users
    op.alter_column('users', 'hashed_password',
               existing_type=sa.String(),
               nullable=True)

    # Add Google-specific columns
    op.add_column('users', sa.Column('is_google_user', sa.Boolean(), nullable=True))
    op.add_column('users', sa.Column('google_user_id', sa.String(), nullable=True))
    op.add_column('users', sa.Column('profile_picture', sa.String(), nullable=True))
    
    # Create unique constraint for google_user_id
    op.create_unique_constraint('uq_users_google_user_id', 'users', ['google_user_id'])
    
    # Update existing rows
    op.execute('UPDATE users SET is_google_user = FALSE WHERE is_google_user IS NULL')
    
    # Make is_google_user non-nullable after setting default value
    op.alter_column('users', 'is_google_user',
                   existing_type=sa.Boolean(),
                   nullable=False)

def downgrade():
    op.drop_constraint('uq_users_google_user_id', 'users', type_='unique')
    op.drop_column('users', 'profile_picture')
    op.drop_column('users', 'google_user_id')
    op.drop_column('users', 'is_google_user')
    op.alter_column('users', 'hashed_password',
                   existing_type=sa.String(),
                   nullable=False)